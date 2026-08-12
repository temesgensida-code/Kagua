%% ============================================================================
%% Kagua Reasoner Engine — Core Logic
%%
%% Provides:
%%   - Dynamic fact assertion/retraction for incoming document data
%%   - Domain rule loading
%%   - find_violations/3 : the main entry-point that asserts facts,
%%     backtracks through all applicable check_violation/2 rules,
%%     and collects matched violations
%% ============================================================================

:- module(engine, [
    find_violations/3,
    assert_facts/1,
    retract_all_facts/0,
    load_domain/1,
    load_domains/1,
    available_domains/1
]).

%% doc_fact/2 is the dynamic predicate populated from incoming JSON.
%% Each fact has the shape:  doc_fact(Key, Value).
%%
%% IMPORTANT: declared in module 'user' so that domain rule modules
%% (which reference doc_fact/2 unqualified) can resolve it.
:- dynamic user:doc_fact/2.

%% Track which domain modules are currently loaded.
:- dynamic loaded_domain/1.

%% ============================================================================
%% Domain Loading
%% ============================================================================

%% available_domains(-Domains)
%% Lists all known domain identifiers.
available_domains([ethiopian_labour_proclamation, employment]).

%% domain_file(+Domain, -Path)
%% Maps a domain atom to its rule file path, relative to the rules/ directory.
domain_file(ethiopian_labour_proclamation, 'rules/employment.pl').
domain_file(employment,                    'rules/employment.pl').

%% domain_module(+Domain, -Module)
%% Maps a domain atom to its Prolog module name.
domain_module(ethiopian_labour_proclamation, employment).
domain_module(employment,                    employment).



%% load_domain(+Domain)
%% Loads a domain rule module if not already loaded.
%% Uses use_module to load, but we do NOT import check_violation/2 into engine
%% to avoid import conflicts. Instead we call it module-qualified.
load_domain(Domain) :-
    loaded_domain(Domain), !.
load_domain(Domain) :-
    domain_file(Domain, RelFile),
    ( exists_file(RelFile)
    -> File = RelFile
    ;  atom_concat('reasoner-engine/', RelFile, FullFile), exists_file(FullFile)
    -> File = FullFile
    ;  File = RelFile
    ),
    use_module(File, []),        %% import nothing — we call module-qualified
    assert(loaded_domain(Domain)).


%% load_domains(+DomainList)
%% Convenience: load a list of domains.
load_domains([]).
load_domains([D|Ds]) :-
    load_domain(D),
    load_domains(Ds).

%% ============================================================================
%% Dynamic Fact Management
%% ============================================================================

%% assert_facts(+FactList)
%% Accepts a list of Key-Value pairs and asserts them as doc_fact/2
%% into the user module so all domain rule modules can see them.
assert_facts([]).
assert_facts([Key-Value | Rest]) :-
    !,
    assert(user:doc_fact(Key, Value)),
    assert_facts(Rest).
assert_facts([Key=Value | Rest]) :-
    !,
    assert(user:doc_fact(Key, Value)),
    assert_facts(Rest).
assert_facts([_ | Rest]) :-
    %% Skip malformed entries
    assert_facts(Rest).

%% retract_all_facts/0
%% Cleans up all dynamically asserted doc_fact/2 predicates.
retract_all_facts :-
    retractall(user:doc_fact(_, _)).

%% ============================================================================
%% Violation Finding — Main Entry Point
%% ============================================================================

%% find_violations(+Domains, +Facts, -Violations)
%%
%% @param Domains   List of domain atoms, e.g. [gdpr, finance], or the atom
%%                  'all' to check against every available domain.
%% @param Facts     List of Key-Value pairs representing document facts.
%% @param Violations  Unified with a list of violation dicts found.
%%
%% Workflow:
%%   1. Retract any previously asserted facts (clean slate).
%%   2. Assert all incoming facts as doc_fact/2.
%%   3. Ensure all requested domain modules are loaded.
%%   4. Backtrack through check_violation/2 across loaded domains
%%      using module-qualified calls.
%%   5. Collect unique violations via findall/3.
%%   6. Clean up asserted facts.

find_violations(DomainsSpec, Facts, Violations) :-
    %% 1. Clean previous state
    retract_all_facts,

    %% 2. Assert incoming facts
    assert_facts(Facts),

    %% 3. Resolve domain list
    resolve_domains(DomainsSpec, Domains),

    %% 4. Ensure domains are loaded
    load_domains(Domains),

    %% 5. Collect violations via backtracking with module-qualified calls
    findall(
        violation{domain: Domain, rule: Rule, title: Title,
                  severity: Sev, description: Desc, recommendation: Rec},
        (
            member(Domain, Domains),
            domain_module(Domain, Mod),
            Mod:check_violation(Domain, V),
            get_dict(rule, V, Rule),
            get_dict(title, V, Title),
            get_dict(severity, V, Sev),
            get_dict(description, V, Desc),
            get_dict(recommendation, V, Rec)
        ),
        ViolationsRaw
    ),

    %% 6. Deduplicate
    sort(ViolationsRaw, Violations),

    %% 7. Clean up
    retract_all_facts.

%% resolve_domains(+Spec, -DomainList)
resolve_domains(all, Domains) :-
    !, available_domains(Domains).
resolve_domains(Domains, Domains) :-
    is_list(Domains), !.
resolve_domains(Single, [Single]) :-
    atom(Single).
