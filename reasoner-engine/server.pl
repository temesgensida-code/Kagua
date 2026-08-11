%% ============================================================================
%% Kagua Reasoner — HTTP Server
%%
%% Minimal SWI-Prolog HTTP wrapper exposing:
%%   POST /reason   — accepts domain + facts JSON, returns violations
%%   GET  /health   — liveness check
%%   GET  /domains  — list available compliance domains
%%
%% Start:  swipl server.pl
%%         (defaults to port 8081, override with env REASONER_PORT)
%% ============================================================================

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_cors)).
:- use_module(library(http/json)).

:- use_module(engine).

%% ---------------------------------------------------------------------------
%% Route Declarations
%% ---------------------------------------------------------------------------

:- http_handler(root(reason),  handle_reason,  [method(post)]).
:- http_handler(root(health),  handle_health,  [method(get)]).
:- http_handler(root(domains), handle_domains, [method(get)]).

%% Enable CORS for all routes
:- set_setting(http:cors, [*]).

%% ---------------------------------------------------------------------------
%% POST /reason
%%
%% Request JSON schema:
%% {
%%   "domain": "gdpr"  |  ["gdpr", "finance"]  |  "all",
%%   "facts": {
%%     "retention_period": "indefinite",
%%     "encryption": "none",
%%     "breach_notification_hours": 96
%%   }
%% }
%%
%% Response JSON:
%% {
%%   "status": "ok",
%%   "domain": ...,
%%   "violations_count": N,
%%   "violations": [ ... ]
%% }
%% ---------------------------------------------------------------------------

handle_reason(Request) :-
    cors_enable(Request, [methods([post])]),
    http_read_json_dict(Request, Body, []),
    %% Extract domain specification
    ( get_dict(domain, Body, DomainRaw) -> true ; DomainRaw = all ),
    %% Extract facts dict
    ( get_dict(facts, Body, FactsDict) -> true ; FactsDict = _{}  ),

    %% Convert domain spec
    parse_domain_spec(DomainRaw, DomainSpec),

    %% Convert JSON dict to Key-Value pair list for the engine
    dict_to_fact_pairs(FactsDict, FactPairs),

    %% Run the reasoning engine
    ( find_violations(DomainSpec, FactPairs, Violations)
    -> true
    ;  Violations = []
    ),

    %% Convert violation dicts to JSON-safe dicts
    maplist(violation_to_json, Violations, JsonViolations),
    length(JsonViolations, Count),

    %% Respond
    reply_json_dict(
        _{
            status: ok,
            domain: DomainRaw,
            violations_count: Count,
            violations: JsonViolations
        }
    ).

%% Error fallback
handle_reason(Request) :-
    cors_enable(Request, [methods([post])]),
    reply_json_dict(
        _{ status: error, message: "Failed to process reasoning request." },
        [status(500)]
    ).

%% ---------------------------------------------------------------------------
%% GET /health
%% ---------------------------------------------------------------------------

handle_health(_Request) :-
    get_time(Now),
    reply_json_dict(
        _{ status: ok, service: "kagua-reasoner", timestamp: Now }
    ).

%% ---------------------------------------------------------------------------
%% GET /domains
%% ---------------------------------------------------------------------------

handle_domains(_Request) :-
    available_domains(Domains),
    reply_json_dict(
        _{ status: ok, domains: Domains }
    ).

%% ============================================================================
%% Helpers
%% ============================================================================

%% parse_domain_spec(+Raw, -Spec)
%% Converts JSON domain value to engine-compatible format.
parse_domain_spec("all", all) :- !.
parse_domain_spec(all, all) :- !.
parse_domain_spec(List, Atoms) :-
    is_list(List), !,
    maplist(to_atom, List, Atoms).
parse_domain_spec(Single, Atom) :-
    to_atom(Single, Atom).

to_atom(X, X) :- atom(X), !.
to_atom(X, A) :- string(X), atom_string(A, X), !.
to_atom(X, X).

%% dict_to_fact_pairs(+Dict, -Pairs)
%% Converts a JSON dict { key: value, ... } to [key-value, ...] pairs.
dict_to_fact_pairs(Dict, Pairs) :-
    is_dict(Dict), !,
    dict_pairs(Dict, _, RawPairs),
    maplist(normalize_pair, RawPairs, Pairs).
dict_to_fact_pairs(_, []).

normalize_pair(Key-Value, AtomKey-NormValue) :-
    to_atom(Key, AtomKey),
    normalize_value(Value, NormValue).

%% normalize_value(+JsonVal, -PrologVal)
%% Converts JSON values to Prolog-friendly representations.
normalize_value(true, true) :- !.
normalize_value(false, false) :- !.
normalize_value(@(true), true) :- !.
normalize_value(@(false), false) :- !.
normalize_value(@(null), null) :- !.
normalize_value(null, null) :- !.
normalize_value(V, V) :- number(V), !.
normalize_value(V, A) :- string(V), atom_string(A, V), !.
normalize_value(V, V) :- atom(V), !.
normalize_value(V, V).

%% violation_to_json(+ViolationDict, -JsonDict)
%% Converts engine violation dict to a clean JSON-serializable dict.
violation_to_json(V, Json) :-
    ( get_dict(domain, V, Domain) -> true ; Domain = unknown ),
    ( get_dict(rule, V, Rule)     -> true ; Rule = "" ),
    ( get_dict(title, V, Title)   -> true ; Title = "" ),
    ( get_dict(severity, V, Sev)  -> true ; Sev = unknown ),
    ( get_dict(description, V, Desc) -> true ; Desc = "" ),
    ( get_dict(recommendation, V, Rec) -> true ; Rec = "" ),
    Json = _{
        domain: Domain,
        rule: Rule,
        title: Title,
        severity: Sev,
        description: Desc,
        recommendation: Rec
    }.

%% ============================================================================
%% Server Startup
%% ============================================================================

start_server :-
    ( getenv('REASONER_PORT', PortStr)
    -> atom_number(PortStr, Port)
    ;  Port = 8081
    ),
    format('[kagua-reasoner] Starting HTTP server on port ~w~n', [Port]),

    %% Pre-load all domain modules at startup
    available_domains(Domains),
    load_domains(Domains),
    format('[kagua-reasoner] Loaded ~w domain rule modules~n', [Domains]),

    http_server(http_dispatch, [port(Port)]),
    format('[kagua-reasoner] Server listening on http://0.0.0.0:~w~n', [Port]),

    %% Block main thread to keep server alive
    thread_get_message(_).

%% Auto-start when loaded
:- initialization(start_server, main).
