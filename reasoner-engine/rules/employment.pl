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
%% Ethiopian Labour Proclamation No. 1156/2019 Rules
%% ---------------------------------------------------------------------------

%% Article 11(3) — Probation Period Limit (Max 60 Working Days)
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 11(3)',
    title:         'Excessive Probation Period',
    severity:      critical,
    description:   Desc,
    recommendation: 'Reduce probation period to a maximum of 60 working days as mandated by Article 11(3) of Ethiopian Labour Proclamation No. 1156/2019.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(probation_days, Days),
    number(Days),
    Days > 60,
    format(atom(Desc),
           'Specified probation period of ~w days exceeds the maximum statutory limit of 60 working days under Article 11(3).',
           [Days]).

%% Article 61(1) — Daily Working Hours Limit (Max 8 Hours/Day)
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 61(1)',
    title:         'Excessive Daily Working Hours',
    severity:      critical,
    description:   Desc,
    recommendation: 'Cap daily normal working hours at 8 hours per day as required by Article 61(1).'
}) :-
    ethiopian_domain(Domain),
    doc_fact(working_hours_per_day, Hrs),
    number(Hrs),
    Hrs > 8,
    format(atom(Desc),
           'Daily working hours (~w hours) exceed the statutory maximum limit of 8 hours per day.',
           [Hrs]).

%% Article 61(1) — Weekly Working Hours Limit (Max 48 Hours/Week)
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 61(1)',
    title:         'Excessive Weekly Working Hours',
    severity:      critical,
    description:   Desc,
    recommendation: 'Reduce weekly normal working hours to a maximum of 48 hours per week as required by Article 61(1).'
}) :-
    ethiopian_domain(Domain),
    doc_fact(weekly_working_hours, Hrs),
    number(Hrs),
    Hrs > 48,
    format(atom(Desc),
           'Weekly working hours (~w hours) exceed the statutory maximum limit of 48 hours per week.',
           [Hrs]).

%% Article 89(1) — Minimum Employment Age (Min 15 Years Old)
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 89(1)',
    title:         'Underage Employment / Minimum Age Violation',
    severity:      critical,
    description:   Desc,
    recommendation: 'Ensure all employees are at least 15 years of age. Employment of persons under 15 is strictly prohibited under Article 89(1).'
}) :-
    ethiopian_domain(Domain),
    doc_fact(minimum_worker_age, Age),
    number(Age),
    Age < 15,
    format(atom(Desc),
           'Minimum employment age (~w years) is below the statutory minimum of 15 years of age.',
           [Age]).

%% Article 77(1) — Minimum Annual Leave (Min 16 Working Days)
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 77(1)',
    title:         'Below Minimum Annual Leave',
    severity:      warning,
    description:   Desc,
    recommendation: 'Grant at least 16 working days of paid annual leave for the first year of service per Article 77(1).'
}) :-
    ethiopian_domain(Domain),
    doc_fact(annual_leave_days, Days),
    number(Days),
    Days < 16,
    format(atom(Desc),
           'Annual leave of ~w working days is below the statutory minimum requirement of 16 working days.',
           [Days]).

%% Article 88(2-3) — Maternity Leave Requirement (120 Consecutive Days)
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 88(2-3)',
    title:         'Insufficient Maternity Leave',
    severity:      critical,
    description:   Desc,
    recommendation: 'Provide 120 consecutive days of fully paid maternity leave (30 days prenatal + 90 days postnatal) per Article 88.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(maternity_leave_days, Days),
    number(Days),
    Days < 120,
    format(atom(Desc),
           'Maternity leave of ~w days is below the mandatory statutory total of 120 consecutive days.',
           [Days]).

%% Article 35 & 44 — Minimum Termination Notice Period (Min 30 Days / 1 Month)
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 35 / 44',
    title:         'Insufficient Termination Notice Period',
    severity:      warning,
    description:   Desc,
    recommendation: 'Ensure termination notice period is at least 30 days (1 month) to comply with statutory requirements under Articles 35 & 44.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(notice_period_days, Days),
    number(Days),
    Days < 30,
    format(atom(Desc),
           'Termination notice period of ~w days is below the minimum statutory requirement of 30 days.',
           [Days]).

%% Helper for domain matching
ethiopian_domain(employment).
ethiopian_domain(ethiopian_labour_proclamation).

