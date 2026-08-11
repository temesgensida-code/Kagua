%% ============================================================================
%% ISO 27001 — Information Security Management System (ISMS)
%%
%% check_violation/2 rules for ISO 27001 Annex A control compliance.
%% ============================================================================

:- module(iso27001, [check_violation/2]).

%% Local wrapper so unqualified doc_fact/2 calls resolve to user:doc_fact/2
doc_fact(K, V) :- user:doc_fact(K, V).

%% ---------------------------------------------------------------------------
%% A.10.1.1 — Policy on Use of Cryptographic Controls
%% ---------------------------------------------------------------------------
check_violation(iso27001, violation{
    rule:    'ISO 27001 A.10.1.1',
    title:   'No Cryptographic Controls Policy',
    severity: critical,
    description: 'Document references data storage but lacks a cryptographic controls policy.',
    recommendation: 'Define a formal policy on the use of cryptographic controls including key management procedures.'
}) :-
    doc_fact(stores_data, true),
    \+ doc_fact(crypto_policy, true).

check_violation(iso27001, violation{
    rule:    'ISO 27001 A.10.1.1',
    title:   'Unencrypted Data Storage',
    severity: critical,
    description: 'Data is stored without encryption, violating cryptographic control requirements.',
    recommendation: 'Enforce AES-256 encryption at rest for all sensitive data and backup archives.'
}) :-
    doc_fact(stores_data, true),
    doc_fact(encryption, none).

%% ---------------------------------------------------------------------------
%% A.9.2.3 — Management of Privileged Access Rights
%% ---------------------------------------------------------------------------
check_violation(iso27001, violation{
    rule:    'ISO 27001 A.9.2.3',
    title:   'Uncontrolled Privileged Access',
    severity: warning,
    description: 'Privileged access rights are not restricted or periodically reviewed.',
    recommendation: 'Implement least-privilege access policies with quarterly access reviews for all admin accounts.'
}) :-
    doc_fact(privileged_access_reviewed, false).

%% ---------------------------------------------------------------------------
%% A.12.6.1 — Management of Technical Vulnerabilities
%% ---------------------------------------------------------------------------
check_violation(iso27001, violation{
    rule:    'ISO 27001 A.12.6.1',
    title:   'Excessive Patch Cycle',
    severity: warning,
    description: Desc,
    recommendation: 'Reduce patching cycle to 30 days maximum for critical security vulnerabilities.'
}) :-
    doc_fact(patch_cycle_days, Days),
    number(Days),
    Days > 30,
    format(atom(Desc),
           'Patching cycle of ~w days exceeds the recommended maximum of 30 days.',
           [Days]).

%% ---------------------------------------------------------------------------
%% A.12.4.1 — Event Logging
%% ---------------------------------------------------------------------------
check_violation(iso27001, violation{
    rule:    'ISO 27001 A.12.4.1',
    title:   'Insufficient Event Logging',
    severity: warning,
    description: 'System event logging is not configured or logs are not retained for an adequate period.',
    recommendation: 'Enable comprehensive event logging and retain logs for a minimum of 12 months.'
}) :-
    doc_fact(event_logging, false).

check_violation(iso27001, violation{
    rule:    'ISO 27001 A.12.4.1',
    title:   'Short Log Retention Period',
    severity: warning,
    description: Desc,
    recommendation: 'Extend log retention to a minimum of 12 months.'
}) :-
    doc_fact(log_retention_months, Months),
    number(Months),
    Months < 12,
    format(atom(Desc),
           'Log retention of ~w months is below the recommended minimum of 12 months.',
           [Months]).

%% ---------------------------------------------------------------------------
%% A.7.2.2 — Information Security Awareness, Education, and Training
%% ---------------------------------------------------------------------------
check_violation(iso27001, violation{
    rule:    'ISO 27001 A.7.2.2',
    title:   'No Security Awareness Training Program',
    severity: warning,
    description: 'No information security awareness or training program is defined.',
    recommendation: 'Establish mandatory annual security awareness training for all employees.'
}) :-
    \+ doc_fact(security_training, true).

%% ---------------------------------------------------------------------------
%% A.17.1 — Information Security Continuity
%% ---------------------------------------------------------------------------
check_violation(iso27001, violation{
    rule:    'ISO 27001 A.17.1',
    title:   'No Business Continuity Plan for Information Security',
    severity: critical,
    description: 'No business continuity or disaster recovery plan is documented for information security.',
    recommendation: 'Develop and regularly test a business continuity plan that addresses information security requirements.'
}) :-
    \+ doc_fact(business_continuity_plan, true).
