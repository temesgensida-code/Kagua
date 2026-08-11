%% ============================================================================
%% Finance — SOX, PCI-DSS, and General Financial Compliance
%%
%% check_violation/2 rules for financial regulatory compliance checking.
%% ============================================================================

:- module(finance, [check_violation/2]).

%% Local wrapper so unqualified doc_fact/2 calls resolve to user:doc_fact/2
doc_fact(K, V) :- user:doc_fact(K, V).

%% ---------------------------------------------------------------------------
%% PCI-DSS Requirement 3.3 — PAN Masking
%% Primary Account Numbers must never be stored in plaintext.
%% ---------------------------------------------------------------------------
check_violation(finance, violation{
    rule:    'PCI-DSS Requirement 3.3',
    title:   'Plaintext PAN Storage Detected',
    severity: critical,
    description: 'Primary Account Numbers (PANs) are stored or logged in plaintext.',
    recommendation: 'Implement immediate tokenization or masking (first 6 / last 4 digits) for all cardholder data at rest and in logs.'
}) :-
    doc_fact(pan_storage, plaintext).

check_violation(finance, violation{
    rule:    'PCI-DSS Requirement 3.3',
    title:   'PAN Logged in Debug Traces',
    severity: critical,
    description: 'Credit card numbers appear in debug or trace log buffers.',
    recommendation: 'Add regex-based masking filters to all logging pipelines to strip PAN patterns before persistence.'
}) :-
    doc_fact(pan_in_logs, true).

%% ---------------------------------------------------------------------------
%% PCI-DSS Requirement 3.4 — Render PAN Unreadable
%% Stored PANs must be rendered unreadable via encryption, hashing, etc.
%% ---------------------------------------------------------------------------
check_violation(finance, violation{
    rule:    'PCI-DSS Requirement 3.4',
    title:   'No Encryption for Stored Cardholder Data',
    severity: critical,
    description: 'Cardholder data at rest is not encrypted or hashed.',
    recommendation: 'Use AES-256 encryption, one-way hashing, or tokenization for all stored cardholder data.'
}) :-
    doc_fact(cardholder_data_encrypted, false).

%% ---------------------------------------------------------------------------
%% PCI-DSS Requirement 8 — Access Control
%% Unique IDs must be assigned to each person with computer access.
%% ---------------------------------------------------------------------------
check_violation(finance, violation{
    rule:    'PCI-DSS Requirement 8',
    title:   'Shared Account Access to Payment Systems',
    severity: warning,
    description: 'Shared or generic accounts are used to access payment processing systems.',
    recommendation: 'Enforce unique user IDs with multi-factor authentication for all payment system access.'
}) :-
    doc_fact(shared_accounts, true).

%% ---------------------------------------------------------------------------
%% SOX Section 302 — Corporate Responsibility for Financial Reports
%% Officers must certify accuracy of financial statements.
%% ---------------------------------------------------------------------------
check_violation(finance, violation{
    rule:    'SOX Section 302',
    title:   'Missing Officer Certification',
    severity: critical,
    description: 'Financial reports lack required officer certification of accuracy.',
    recommendation: 'Ensure CEO and CFO sign off on all periodic financial reports per SOX Section 302.'
}) :-
    doc_fact(officer_certification, false).

check_violation(finance, violation{
    rule:    'SOX Section 302',
    title:   'No Officer Certification Clause',
    severity: warning,
    description: 'Document does not reference officer certification requirements for financial disclosures.',
    recommendation: 'Add explicit SOX Section 302 certification language to financial reporting procedures.'
}) :-
    \+ doc_fact(officer_certification, _).

%% ---------------------------------------------------------------------------
%% SOX Section 404 — Internal Controls Assessment
%% Internal controls over financial reporting must be documented and tested.
%% ---------------------------------------------------------------------------
check_violation(finance, violation{
    rule:    'SOX Section 404',
    title:   'Insufficient Internal Control Documentation',
    severity: warning,
    description: 'Internal controls over financial reporting are not adequately documented.',
    recommendation: 'Document and test all material internal controls annually; maintain audit trails.'
}) :-
    doc_fact(internal_controls_documented, false).

check_violation(finance, violation{
    rule:    'SOX Section 404',
    title:   'Audit Trail Gaps',
    severity: critical,
    description: Desc,
    recommendation: 'Implement continuous audit logging with tamper-proof storage for all financial transactions.'
}) :-
    doc_fact(audit_trail, incomplete),
    format(atom(Desc),
           'Audit trail for financial transactions is incomplete, violating SOX Section 404 requirements.',
           []).

%% ---------------------------------------------------------------------------
%% General — Monetary Threshold Alerts
%% Flag transactions or amounts exceeding policy thresholds.
%% ---------------------------------------------------------------------------
check_violation(finance, violation{
    rule:    'Internal Policy',
    title:   'Transaction Exceeds Approval Threshold',
    severity: warning,
    description: Desc,
    recommendation: 'Require dual-authorization for transactions exceeding the defined threshold.'
}) :-
    doc_fact(transaction_amount, Amount),
    doc_fact(approval_threshold, Threshold),
    number(Amount), number(Threshold),
    Amount > Threshold,
    format(atom(Desc),
           'Transaction amount $~w exceeds the approval threshold of $~w.',
           [Amount, Threshold]).

%% ---------------------------------------------------------------------------
%% Anti-Money Laundering — Suspicious Activity
%% ---------------------------------------------------------------------------
check_violation(finance, violation{
    rule:    'AML/BSA',
    title:   'No SAR Filing Procedure',
    severity: warning,
    description: 'Document does not define a Suspicious Activity Report (SAR) filing procedure.',
    recommendation: 'Establish procedures for identifying and filing SARs within mandated timeframes.'
}) :-
    doc_fact(domain_context, payments),
    \+ doc_fact(sar_procedure, true).
