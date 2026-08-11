%% ============================================================================
%% Employment — Labour Law & HR Compliance
%%
%% check_violation/2 rules for employment and workplace regulatory compliance.
%% ============================================================================

:- module(employment, [check_violation/2]).

:- discontiguous check_violation/2.

%% Local wrapper so unqualified doc_fact/2 calls resolve to user:doc_fact/2
doc_fact(K, V) :- user:doc_fact(K, V).

%% ---------------------------------------------------------------------------
%% At-Will Clause — Required Notice Period
%% Certain jurisdictions require minimum notice periods for termination.
%% ---------------------------------------------------------------------------
check_violation(employment, violation{
    rule:    'Employment Standards',
    title:   'Missing Termination Notice Period',
    severity: warning,
    description: 'Employment agreement does not specify a notice period for termination.',
    recommendation: 'Include a minimum notice period clause (e.g., 30 days) as required by applicable labor law.'
}) :-
    \+ doc_fact(notice_period_days, _).

check_violation(employment, violation{
    rule:    'Employment Standards',
    title:   'Insufficient Notice Period',
    severity: warning,
    description: Desc,
    recommendation: 'Increase notice period to at least 30 days to comply with standard employment regulations.'
}) :-
    doc_fact(notice_period_days, Days),
    number(Days),
    Days < 30,
    format(atom(Desc),
           'Notice period of ~w days is below the recommended minimum of 30 days.',
           [Days]).

%% ---------------------------------------------------------------------------
%% Non-Compete — Excessive Scope
%% Non-compete clauses must be reasonable in scope, duration, and geography.
%% ---------------------------------------------------------------------------
check_violation(employment, violation{
    rule:    'Non-Compete Reasonableness',
    title:   'Excessive Non-Compete Duration',
    severity: warning,
    description: Desc,
    recommendation: 'Reduce non-compete duration to 12 months or less; many jurisdictions void excessive restrictions.'
}) :-
    doc_fact(non_compete_months, Months),
    number(Months),
    Months > 24,
    format(atom(Desc),
           'Non-compete duration of ~w months exceeds reasonable limits (typically 12-24 months).',
           [Months]).

check_violation(employment, violation{
    rule:    'Non-Compete Enforceability',
    title:   'Non-Compete in Restricted Jurisdiction',
    severity: critical,
    description: Desc,
    recommendation: 'Remove or narrow the non-compete clause; it may be unenforceable in the specified jurisdiction.'
}) :-
    doc_fact(non_compete_present, true),
    doc_fact(jurisdiction, Jurisdiction),
    non_compete_banned(Jurisdiction),
    format(atom(Desc),
           'Non-compete clause present but may be unenforceable in ~w.',
           [Jurisdiction]).

non_compete_banned('California').
non_compete_banned('North Dakota').
non_compete_banned('Oklahoma').
non_compete_banned('Minnesota').
non_compete_banned('Colorado').

%% ---------------------------------------------------------------------------
%% Minimum Wage Compliance
%% ---------------------------------------------------------------------------
check_violation(employment, violation{
    rule:    'Fair Labor Standards Act',
    title:   'Below Minimum Wage',
    severity: critical,
    description: Desc,
    recommendation: 'Adjust compensation to meet or exceed applicable minimum wage requirements.'
}) :-
    doc_fact(hourly_rate, Rate),
    doc_fact(minimum_wage, MinWage),
    number(Rate), number(MinWage),
    Rate < MinWage,
    format(atom(Desc),
           'Specified hourly rate $~2f is below the minimum wage of $~2f.',
           [Rate, MinWage]).

%% ---------------------------------------------------------------------------
%% Worker Classification
%% Misclassifying employees as independent contractors is a violation.
%% ---------------------------------------------------------------------------
check_violation(employment, violation{
    rule:    'Worker Classification',
    title:   'Potential Misclassification Risk',
    severity: warning,
    description: 'Agreement classifies the worker as an independent contractor but includes clauses typical of employment (fixed hours, exclusive service, employer-provided tools).',
    recommendation: 'Review classification against IRS/DOL tests (ABC test or economic reality test) and reclassify if necessary.'
}) :-
    doc_fact(worker_type, contractor),
    doc_fact(fixed_hours, true).

check_violation(employment, violation{
    rule:    'Worker Classification',
    title:   'Potential Misclassification Risk',
    severity: warning,
    description: 'Contractor agreement requires exclusive service, which is an indicator of an employment relationship.',
    recommendation: 'Remove exclusivity requirement or reclassify worker as an employee.'
}) :-
    doc_fact(worker_type, contractor),
    doc_fact(exclusive_service, true).

%% ---------------------------------------------------------------------------
%% Discrimination & Equal Opportunity
%% ---------------------------------------------------------------------------
check_violation(employment, violation{
    rule:    'Equal Employment Opportunity',
    title:   'Missing Anti-Discrimination Clause',
    severity: warning,
    description: 'Employment agreement lacks an equal opportunity / anti-discrimination statement.',
    recommendation: 'Include a comprehensive EEO statement covering protected classes under Title VII and applicable state laws.'
}) :-
    \+ doc_fact(anti_discrimination_clause, true).

%% ---------------------------------------------------------------------------
%% Arbitration — Mandatory Arbitration Concerns
%% ---------------------------------------------------------------------------
check_violation(employment, violation{
    rule:    'Ending Forced Arbitration Act',
    title:   'Mandatory Arbitration for Harassment Claims',
    severity: critical,
    description: 'Mandatory arbitration clause covers sexual harassment or assault claims, which may violate federal law.',
    recommendation: 'Exclude sexual harassment and assault claims from mandatory arbitration per the Ending Forced Arbitration Act of 2022.'
}) :-
    doc_fact(mandatory_arbitration, true),
    doc_fact(arbitration_covers_harassment, true).
