%% ============================================================================
%% Ethiopian Labour Proclamation No. 1156/2019 Compliance Rules Module
%%
%% SWI-Prolog check_violation/2 rules for verifying employment contracts
%% against the statutory provisions of Ethiopian Labour Proclamation No. 1156/2019.
%% ============================================================================

:- module(employment, [check_violation/2]).

:- discontiguous check_violation/2.

%% Local wrapper so unqualified doc_fact/2 calls resolve to user:doc_fact/2
doc_fact(K, V) :- user:doc_fact(K, V).

%% Helper for domain matching
ethiopian_domain(employment).
ethiopian_domain(ethiopian_labour_proclamation).

%% ---------------------------------------------------------------------------
%% Article 11(3) — Probation Period Limit (Max 60 Working Days)
%% ---------------------------------------------------------------------------
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
           'Specified probation period of ~w days exceeds the statutory limit of 60 working days under Article 11(3).',
           [Days]).

%% ---------------------------------------------------------------------------
%% Article 61(1) — Daily Working Hours Limit (Max 8 Hours/Day)
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 61(1)',
    title:         'Excessive Daily Working Hours',
    severity:      critical,
    description:   Desc,
    recommendation: 'Cap normal daily working hours at 8 hours per day as mandated by Article 61(1).'
}) :-
    ethiopian_domain(Domain),
    doc_fact(working_hours_per_day, Hrs),
    number(Hrs),
    Hrs > 8,
    format(atom(Desc),
           'Daily working hours (~w hours) exceed the statutory maximum limit of 8 hours per day.',
           [Hrs]).

%% ---------------------------------------------------------------------------
%% Article 61(1) — Weekly Working Hours Limit (Max 48 Hours/Week)
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 61(1)',
    title:         'Excessive Weekly Working Hours',
    severity:      critical,
    description:   Desc,
    recommendation: 'Reduce normal weekly working hours to a maximum of 48 hours per week as mandated by Article 61(1).'
}) :-
    ethiopian_domain(Domain),
    doc_fact(weekly_working_hours, Hrs),
    number(Hrs),
    Hrs > 48,
    format(atom(Desc),
           'Weekly working hours (~w hours) exceed the statutory maximum limit of 48 hours per week.',
           [Hrs]).

%% ---------------------------------------------------------------------------
%% Article 89(1) — Minimum Employment Age (Min 15 Years Old)
%% ---------------------------------------------------------------------------
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

%% ---------------------------------------------------------------------------
%% Article 77(1) — Minimum Annual Leave (Min 16 Working Days)
%% ---------------------------------------------------------------------------
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

%% ---------------------------------------------------------------------------
%% Article 88(2-3) — Maternity Leave Requirement (120 Consecutive Days)
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 88(2-3)',
    title:         'Insufficient Maternity Leave',
    severity:      critical,
    description:   Desc,
    recommendation: 'Provide 120 consecutive days of fully paid maternity leave (30 days prenatal + 90 days postnatal) as required by Article 88.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(maternity_leave_days, Days),
    number(Days),
    Days < 120,
    format(atom(Desc),
           'Maternity leave of ~w days is below the mandatory statutory total of 120 consecutive days.',
           [Days]).

%% ---------------------------------------------------------------------------
%% Article 35 & 44 — Minimum Termination Notice Period (Min 30 Days / 1 Month)
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Articles 35 & 44',
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

%% ---------------------------------------------------------------------------
%% Article 14(1)(f) — Anti-Discrimination Policy Requirement
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 14(1)(f)',
    title:         'Missing Anti-Discrimination Policy',
    severity:      warning,
    description:   'Employment contract lacks an anti-discrimination statement covering gender, nationality, religion, or HIV/AIDS status.',
    recommendation: 'Incorporate an explicit anti-discrimination clause in compliance with Article 14(1)(f).'
}) :-
    ethiopian_domain(Domain),
    \+ doc_fact(has_anti_discrimination, true).

%% ---------------------------------------------------------------------------
%% Article 14(1)(h) — Sexual Harassment Policy Requirement
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 14(1)(h)',
    title:         'Missing Sexual Harassment Protection Policy',
    severity:      critical,
    description:   'Contract lacks an explicit prohibition or policy regarding sexual harassment or sexual assault in the workplace.',
    recommendation: 'Include a clear zero-tolerance sexual harassment policy per Article 14(1)(h).'
}) :-
    ethiopian_domain(Domain),
    \+ doc_fact(has_sexual_harassment_policy, true).

%% ---------------------------------------------------------------------------
%% Article 67 — Excessive Overtime Hours Limit (Max 2 Hours/Day)
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 67',
    title:         'Excessive Daily Overtime Hours',
    severity:      warning,
    description:   Desc,
    recommendation: 'Cap overtime work to a maximum of 2 hours per day as mandated by Article 67.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(overtime_hours_per_day, Hrs),
    number(Hrs),
    Hrs > 2,
    format(atom(Desc),
           'Daily overtime hours (~w hours) exceed the statutory maximum limit of 2 hours per day.',
           [Hrs]).

%% ---------------------------------------------------------------------------
%% Article 85 — Minimum Sick Leave Entitlement (Min 6 Months)
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 85',
    title:         'Insufficient Sick Leave Duration',
    severity:      warning,
    description:   Desc,
    recommendation: 'Ensure sick leave provision allows for up to 6 months of medical leave with graduated pay per Article 85.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(sick_leave_months, Months),
    number(Months),
    Months < 6,
    format(atom(Desc),
           'Sick leave duration (~w months) is below the statutory maximum entitlement of 6 months under Article 85.',
           [Months]).

%% ---------------------------------------------------------------------------
%% Article 39 — Severance Pay Provision Requirement
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 39',
    title:         'Missing Severance Pay Provision',
    severity:      warning,
    description:   'Employment contract lacks explicit severance pay provisions upon lawful termination or retrenchment.',
    recommendation: 'Incorporate severance pay terms calculating at least 30 times the daily wage for the first year of service per Article 39.'
}) :-
    ethiopian_domain(Domain),
    \+ doc_fact(has_severance_provision, true).

%% ---------------------------------------------------------------------------
%% Article 6 — Written Employment Contract / Letter Requirement
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 6',
    title:         'Missing Written Contract Provision',
    severity:      warning,
    description:   'Contract does not stipulate the issuance of a written employment contract or signed letter within 15 days of employment.',
    recommendation: 'Include a clause guaranteeing a written employment document within 15 days of commencement per Article 6.'
}) :-
    ethiopian_domain(Domain),
    \+ doc_fact(has_written_contract_provision, true).

%% ---------------------------------------------------------------------------
%% Article 90 — Young Worker Daily Hours Limit (Max 7 Hours/Day for ages 15-18)
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 90',
    title:         'Excessive Working Hours for Young Worker',
    severity:      critical,
    description:   Desc,
    recommendation: 'Cap daily working hours at 7 hours per day for young workers between 15 and 18 years of age per Article 90.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(minimum_worker_age, Age),
    number(Age),
    Age >= 15,
    Age < 18,
    doc_fact(working_hours_per_day, Hrs),
    number(Hrs),
    Hrs > 7,
    format(atom(Desc),
           'Young worker (~w years old) assigned daily working hours (~w hours) exceeding the 7 hours/day statutory cap under Article 90.',
           [Age, Hrs]).



