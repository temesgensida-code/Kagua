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

%% ---------------------------------------------------------------------------
%% Article 14(1)(b-c) & 87 — Hiring Discrimination (Sex, Religion, Marital Status)
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Articles 14(1)(b-c) & 87',
    title:         'Discriminatory Hiring Criteria',
    severity:      critical,
    description:   'Vacancy or contract restricts applicants by sex, gender, religion, or marital status, violating equal opportunity principles.',
    recommendation: 'Remove all discriminatory restrictions based on sex, religion, or marital status per Articles 14(1)(b-c) and 87.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(hiring_discrimination_detected, true).

%% ---------------------------------------------------------------------------
%% Article 14(1)(b) & 88 — Pregnancy Discrimination / Forced Resignation
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Articles 14(1)(b) & 88',
    title:         'Pregnancy Discrimination & Mandatory Resignation',
    severity:      critical,
    description:   'Contract excludes pregnant applicants or mandates resignation/termination upon pregnancy or childbirth.',
    recommendation: 'Eliminate all clauses discriminating against pregnant workers or forcing resignation upon childbirth under Articles 14 and 88.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(pregnancy_discrimination_detected, true).

%% ---------------------------------------------------------------------------
%% Article 68 — Unpaid Mandatory Overtime
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 68',
    title:         'Unpaid Mandatory Overtime Work',
    severity:      critical,
    description:   'Contract requires mandatory overtime without providing statutory overtime premium rates (1.25x - 2.5x base rate).',
    recommendation: 'Ensure all overtime work is compensated at statutory rates (1.25x to 2.5x) as mandated by Article 68.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(unpaid_overtime_detected, true).

%% ---------------------------------------------------------------------------
%% Article 70 — Denial of Mandatory Weekly Rest Day
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 70',
    title:         'Denial of Mandatory Weekly Rest Day',
    severity:      critical,
    description:   'Contract requires continuous work without guaranteeing at least 24 consecutive hours of weekly rest.',
    recommendation: 'Grant all workers at least 24 consecutive hours of weekly rest every 7 days as mandated by Article 70.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(weekly_rest_denied, true).

%% ---------------------------------------------------------------------------
%% Article 77(1) & (4) — Multi-Year Annual Leave Denial / Forfeiture
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 77(1) & (4)',
    title:         'Denial or Multi-Year Delay of Paid Annual Leave',
    severity:      critical,
    description:   'Contract denies paid annual leave during initial years of service or enforces forfeiture of annual leave entitlement.',
    recommendation: 'Provide a minimum of 16 working days paid annual leave starting from the first year of service per Article 77.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(annual_leave_denied_initial_years, true).

%% ---------------------------------------------------------------------------
%% Article 88(2-3) — Denial of Paid Maternity Leave
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 88(2-3)',
    title:         'Denial of Fully Paid Maternity Leave',
    severity:      critical,
    description:   'Contract fails to grant 120 consecutive days of fully paid maternity leave (30 days prenatal + 90 days postnatal).',
    recommendation: 'Grant female workers 120 consecutive days of fully paid maternity leave in accordance with Article 88.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(maternity_leave_denied, true).

%% ---------------------------------------------------------------------------
%% Articles 39 & 40 — Blanket Forfeiture of Severance Pay
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Articles 39 & 40',
    title:         'Blanket Forfeiture / Waiver of Statutory Severance Pay',
    severity:      critical,
    description:   'Contract stipulates blanket forfeiture or pre-waiver of statutory severance pay upon termination.',
    recommendation: 'Remove severance forfeiture clauses; severance pay is a statutory right upon qualifying termination under Articles 39 & 40.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(severance_forfeited, true).

%% ---------------------------------------------------------------------------
%% Articles 92 & 93 — Illegal Cost-Shifting of PPE to Workers
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Articles 92 & 93',
    title:         'Illegal Cost-Shifting of Personal Protective Equipment (PPE)',
    severity:      critical,
    description:   'Contract requires workers to purchase or pay for their own Personal Protective Equipment (PPE) and occupational safety gear.',
    recommendation: 'Employer must provide all necessary PPE and safety equipment free of charge under Articles 92 & 93.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(worker_pays_ppe, true).

%% ---------------------------------------------------------------------------
%% Article 181 — Unlawful Restriction of Access to Labour Inspectors
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 181',
    title:         'Unlawful Restriction of Access to Labour Inspectors',
    severity:      critical,
    description:   'Contract prohibits or restricts workers from contacting government labour inspectors or reporting violations.',
    recommendation: 'Delete prohibitions against contacting labour inspectors; worker access to inspectorate is protected under Article 181.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(prohibits_labour_inspection, true).

%% ---------------------------------------------------------------------------
%% Article 90 — Young Workers Full Adult Work Schedule
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 90',
    title:         'Young Workers (15-17) Assigned Full Adult Schedule',
    severity:      critical,
    description:   'Contract assigns young workers (ages 15-17) to full adult 8+ hour daily work schedules instead of the statutory 7-hour cap.',
    recommendation: 'Limit daily work to maximum 7 hours/day for young workers between 15 and 18 years per Article 90.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(young_worker_adult_schedule, true).

%% ---------------------------------------------------------------------------
%% Articles 14(1)(a) & 26(2)(a) — Trade Union Prohibition & Union Termination
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Articles 14(1)(a) & 26(2)(a)',
    title:         'Prohibition of Trade Union Membership & Illegal Union Termination',
    severity:      critical,
    description:   'Contract bans trade union membership or threatens termination for joining or participating in trade union activities.',
    recommendation: 'Remove prohibitions against trade union membership; freedom of association is guaranteed under Articles 14 & 26.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(trade_union_prohibited, true).

%% ---------------------------------------------------------------------------
%% Part Nine (Article 138+) — Pre-Waiver of Dispute Resolution & Appeal Rights
%% ---------------------------------------------------------------------------
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 138 (Part Nine)',
    title:         'Unlawful Pre-Waiver of Statutory Dispute Resolution Rights',
    severity:      critical,
    description:   'Contract forces workers to pre-waive their right to appeal dismissals to the Labour Relations Board or courts.',
    recommendation: 'Eliminate dispute waiver clauses; rights to appeal to Labour Boards and courts under Part Nine cannot be waived as a condition of employment.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(dispute_appeal_waived, true).


%% ============================================================================
%% Three-Valued Logic: Ambiguity Warning Rules (Phase 4)
%%
%% Triggered when a clause TYPE was detected by NER (has_*_clause = true)
%% but the numeric value could not be extracted from the document text.
%% These fire `severity: warning` to flag clauses requiring manual review
%% instead of silently passing as compliant.
%% ============================================================================

%% Article 11(3) — Probation clause detected but duration not parseable
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 11(3)',
    title:         'Ambiguous Probation Period Duration',
    severity:      warning,
    description:   'Contract contains a probation clause but the exact duration in days or months could not be determined. Manual review required to confirm compliance with the 60 working day limit.',
    recommendation: 'Explicitly state the probation period in working days (maximum 60) as required by Article 11(3).'
}) :-
    ethiopian_domain(Domain),
    doc_fact(has_probation_clause, true),
    \+ doc_fact(probation_days, _).

%% Article 61(1) — Working hours clause detected but hours not parseable
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 61(1)',
    title:         'Ambiguous Working Hours Specification',
    severity:      warning,
    description:   'Contract references working hours but exact daily or weekly figures could not be determined. Manual review required to confirm compliance with the 8 hrs/day and 48 hrs/week limits.',
    recommendation: 'State precise daily and weekly working hours (max 8 hrs/day, 48 hrs/week) per Article 61(1).'
}) :-
    ethiopian_domain(Domain),
    doc_fact(has_working_hours_clause, true),
    \+ doc_fact(working_hours_per_day, _),
    \+ doc_fact(weekly_working_hours, _).

%% Article 77(1) — Annual leave clause detected but days not parseable
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 77(1)',
    title:         'Ambiguous Annual Leave Duration',
    severity:      warning,
    description:   'Contract references annual leave but the number of working days could not be extracted. Manual review required to confirm the statutory minimum of 16 working days.',
    recommendation: 'Specify at least 16 working days of paid annual leave per Article 77(1).'
}) :-
    ethiopian_domain(Domain),
    doc_fact(has_annual_leave_clause, true),
    \+ doc_fact(annual_leave_days, _).

%% Article 88(2-3) — Maternity leave clause detected but days not parseable
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 88(2-3)',
    title:         'Ambiguous Maternity Leave Duration',
    severity:      warning,
    description:   'Contract references maternity leave but the total consecutive days could not be determined. Manual review required to confirm the mandatory 120-day minimum.',
    recommendation: 'Provide exactly 120 consecutive days of fully paid maternity leave (30 prenatal + 90 postnatal) per Article 88.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(has_maternity_leave_clause, true),
    \+ doc_fact(maternity_leave_days, _).

%% Articles 35 & 44 — Termination notice clause detected but period not parseable
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Articles 35 & 44',
    title:         'Ambiguous Termination Notice Period',
    severity:      warning,
    description:   'Contract contains a termination notice clause but the exact duration in days could not be determined. Manual review required to confirm the statutory 30-day minimum.',
    recommendation: 'Specify a minimum termination notice period of 30 days in writing per Articles 35 & 44.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(has_termination_notice_clause, true),
    \+ doc_fact(notice_period_days, _).

%% Article 39 — Severance clause detected but terms ambiguous
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 39',
    title:         'Ambiguous Severance Pay Terms',
    severity:      warning,
    description:   'Contract references severance or termination compensation but the calculation or entitlement terms could not be verified. Manual review required.',
    recommendation: 'State severance pay terms clearly: at least 30 times the daily wage per year of service per Article 39.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(has_severance_provision, true),
    \+ doc_fact(severance_forfeited, _).


%% ============================================================================
%% Additional Statutory Violation Rules (Addressing Missed Fictional Vacancy Issues)
%% ============================================================================

%% Article 61(2) — Weekly Working Hours Exceed 48 Hours
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 61(2)',
    title:         'Excessive Weekly Working Hours',
    severity:      critical,
    description:   'Contract establishes a weekly schedule of ~W hours, exceeding the statutory maximum of 48 normal working hours per week.',
    recommendation: 'Reduce weekly working hours to 48 hours or fewer per Article 61(2).'
}) :-
    ethiopian_domain(Domain),
    doc_fact(weekly_working_hours, W),
    W > 48.

%% Article 71(1) — Routine Sunday / Weekly Rest Day Work
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 71(1)',
    title:         'Routine Work Scheduled on Weekly Rest Day',
    severity:      critical,
    description:   'Contract schedules work on the weekly rest day (Sunday) as a standard routine duty rather than limiting rest day work to exceptional emergency circumstances.',
    recommendation: 'Restrict weekly rest day work strictly to exceptional circumstances defined in Article 71(1).'
}) :-
    ethiopian_domain(Domain),
    doc_fact(routine_rest_day_work_detected, true).

%% Article 67(2) — Weekly Overtime Exceeds 12 Hours
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 67(2)',
    title:         'Excessive Weekly Overtime Limit',
    severity:      critical,
    description:   'Contract overtime schedule totals ~OT hours per week, breaching the statutory cap of 12 hours of overtime per week.',
    recommendation: 'Cap overtime hours to a maximum of 4 hours per day and 12 hours per week per Article 67(2).'
}) :-
    ethiopian_domain(Domain),
    doc_fact(overtime_hours_per_week, OT),
    OT > 12.

%% Article 59(2) — Wage Deductions Exceed 1/3 Ceiling (33.3%)
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 59(2)',
    title:         'Excessive Wage Deduction Ceiling',
    severity:      critical,
    description:   'Contract sets maximum wage deduction ceiling at ~PCT%, exceeding the statutory limit of one-third (33.3%) of monthly wages.',
    recommendation: 'Lower maximum wage deduction ceiling to no more than one-third (33.3%) of worker monthly remuneration per Article 59(2).'
}) :-
    ethiopian_domain(Domain),
    doc_fact(max_wage_deduction_percent, PCT),
    PCT > 33.

%% Article 59(1) — Unlawful Resignation Wage Penalty
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 59(1)',
    title:         'Unlawful Wage Withholding Resignation Penalty',
    severity:      critical,
    description:   'Contract imposes a service completion charge or wage withholding penalty for early resignation, which is not among lawful statutory wage deduction grounds.',
    recommendation: 'Remove mandatory wage withholding penalties for employee resignation per Article 59(1).'
}) :-
    ethiopian_domain(Domain),
    doc_fact(unlawful_wage_deduction_detected, true).

%% Article 36 — Final Settlement Delayed Beyond 7 Working Days
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 36',
    title:         'Delayed Final Settlement Payment Period',
    severity:      critical,
    description:   'Contract defers final settlement processing up to ~DAYS days, exceeding the statutory requirement to settle all termination payments within 7 working days.',
    recommendation: 'Specify that all final wages and statutory entitlements must be settled within 7 working days of termination per Article 36.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(final_settlement_days, DAYS),
    DAYS > 7.

%% Article 91(1-3) — Prohibited Night & Rest-Day Shift Assignment for Young Workers
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 91(1-3)',
    title:         'Prohibited Shift Assignment for Young Workers',
    severity:      critical,
    description:   'Young workers (ages 15-17) are assigned to night shifts (10 p.m. to 6 a.m.) or weekly rest days (Sunday sessions), violating statutory protections for minors.',
    recommendation: 'Exclude young workers from night shifts (10 p.m. to 6 a.m.), overtime, and weekly rest day shifts per Article 91.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(young_worker_night_work_detected, true).

%% Article 87(6) — At-Will Termination Risk for Pregnant Employees
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 87(6)',
    title:         'Termination Protection Violation for Pregnant Workers',
    severity:      critical,
    description:   'Contract provides for convenience/at-will termination without cause while subjecting extended maternity leave to staffing level reviews, creating risk of unlawful dismissal during pregnancy or maternity.',
    recommendation: 'Explicitly guarantee that employment cannot be terminated during pregnancy or within four months following confinement per Article 87(6).'
}) :-
    ethiopian_domain(Domain),
    doc_fact(pregnant_worker_termination_risk, true).

%% Article 86 — Reduced First-Month Sick Leave Payment Rate
check_violation(Domain, violation{
    rule:          'Ethiopian Labour Proclamation No. 1156/2019 - Article 86',
    title:         'Sub-Statutory First-Month Sick Leave Payment Rate',
    severity:      critical,
    description:   'Contract pays sick leave at ~RATE% for the first month, below the statutory requirement of 100% full wage pay during the first month of certified sick leave.',
    recommendation: 'Ensure sick leave is paid at 100% of wage for the first month, 50% for the next two months, per Article 86.'
}) :-
    ethiopian_domain(Domain),
    doc_fact(sick_leave_first_month_rate_percent, RATE),
    RATE < 100.

