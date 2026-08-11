%% ============================================================================
%% GDPR — General Data Protection Regulation (EU 2016/679)
%%
%% Domain-specific violation rules for GDPR compliance checking.
%% Each check_violation/2 clause matches against dynamically asserted
%% document facts and produces a structured violation term.
%% ============================================================================

:- module(gdpr, [check_violation/2]).

%% Local wrapper so unqualified doc_fact/2 calls resolve to user:doc_fact/2
doc_fact(K, V) :- user:doc_fact(K, V).

%% ---------------------------------------------------------------------------
%% Article 5(1)(e) — Storage Limitation
%% Data must not be kept longer than necessary for its stated purpose.
%% ---------------------------------------------------------------------------
check_violation(gdpr, violation{
    rule:    'GDPR Article 5(1)(e)',
    title:   'Storage Limitation Violation',
    severity: critical,
    description: Desc,
    recommendation: 'Define explicit retention periods and implement automated deletion schedules.'
}) :-
    doc_fact(retention_period, indefinite),
    format(atom(Desc),
           'Document specifies indefinite data retention, violating the storage limitation principle.',
           []).

check_violation(gdpr, violation{
    rule:    'GDPR Article 5(1)(e)',
    title:   'Excessive Retention Period',
    severity: warning,
    description: Desc,
    recommendation: 'Review retention duration; ensure it is proportionate to the processing purpose.'
}) :-
    doc_fact(retention_period, Months),
    number(Months),
    Months > 60,
    format(atom(Desc),
           'Retention period of ~w months exceeds recommended maximum of 60 months.',
           [Months]).

%% ---------------------------------------------------------------------------
%% Article 6(1) — Lawfulness of Processing
%% Processing must have a valid legal basis (consent, contract, etc.).
%% ---------------------------------------------------------------------------
check_violation(gdpr, violation{
    rule:    'GDPR Article 6(1)',
    title:   'Missing Legal Basis for Processing',
    severity: critical,
    description: 'No lawful basis for data processing is specified in the document.',
    recommendation: 'Explicitly state the legal basis (consent, contract, legal obligation, etc.) for each processing activity.'
}) :-
    \+ doc_fact(legal_basis, _).

%% ---------------------------------------------------------------------------
%% Article 13 — Right to Information / Transparency
%% Data subjects must be informed about processing purposes.
%% ---------------------------------------------------------------------------
check_violation(gdpr, violation{
    rule:    'GDPR Article 13',
    title:   'Insufficient Data Subject Notification',
    severity: warning,
    description: 'Document lacks a privacy notice or data processing transparency clause.',
    recommendation: 'Include a clear privacy notice describing what data is collected, for what purpose, and how long it is retained.'
}) :-
    \+ doc_fact(privacy_notice, true).

%% ---------------------------------------------------------------------------
%% Article 17 — Right to Erasure
%% Data subjects must be able to request deletion of their personal data.
%% ---------------------------------------------------------------------------
check_violation(gdpr, violation{
    rule:    'GDPR Article 17',
    title:   'No Erasure Mechanism',
    severity: warning,
    description: 'Document does not mention a right-to-erasure or data deletion procedure.',
    recommendation: 'Provide a documented process for data subjects to request and obtain deletion of their personal data.'
}) :-
    \+ doc_fact(erasure_mechanism, true).

%% ---------------------------------------------------------------------------
%% Article 25 — Data Protection by Design and by Default
%% Encryption and pseudonymization must be considered.
%% ---------------------------------------------------------------------------
check_violation(gdpr, violation{
    rule:    'GDPR Article 25',
    title:   'No Encryption at Rest',
    severity: critical,
    description: Desc,
    recommendation: 'Mandate AES-256 or equivalent encryption for all stored personal data.'
}) :-
    doc_fact(encryption, none),
    format(atom(Desc),
           'Personal data is stored without encryption, violating data protection by design requirements.',
           []).

check_violation(gdpr, violation{
    rule:    'GDPR Article 25',
    title:   'Weak Encryption Standard',
    severity: warning,
    description: Desc,
    recommendation: 'Upgrade to AES-256 or an equivalent modern standard.'
}) :-
    doc_fact(encryption, Standard),
    atom(Standard),
    Standard \= none,
    \+ member(Standard, ['AES-256', 'AES-128', aes_256, aes_128]),
    format(atom(Desc),
           'Encryption standard "~w" may not meet GDPR adequacy requirements.',
           [Standard]).

%% ---------------------------------------------------------------------------
%% Article 33 — Breach Notification
%% Supervisory authority must be notified within 72 hours of a breach.
%% ---------------------------------------------------------------------------
check_violation(gdpr, violation{
    rule:    'GDPR Article 33',
    title:   'Missing Breach Notification Procedure',
    severity: warning,
    description: 'No data breach notification timeline or procedure is defined.',
    recommendation: 'Include a 72-hour breach notification procedure to the supervisory authority.'
}) :-
    \+ doc_fact(breach_notification_hours, _).

check_violation(gdpr, violation{
    rule:    'GDPR Article 33',
    title:   'Breach Notification Exceeds 72 Hours',
    severity: critical,
    description: Desc,
    recommendation: 'Reduce breach notification window to 72 hours or less.'
}) :-
    doc_fact(breach_notification_hours, Hours),
    number(Hours),
    Hours > 72,
    format(atom(Desc),
           'Breach notification window is ~w hours, exceeding the 72-hour GDPR mandate.',
           [Hours]).

%% ---------------------------------------------------------------------------
%% Article 44–49 — International Data Transfers
%% Transfers outside the EEA require adequacy decisions or safeguards.
%% ---------------------------------------------------------------------------
check_violation(gdpr, violation{
    rule:    'GDPR Articles 44-49',
    title:   'Unprotected International Data Transfer',
    severity: critical,
    description: Desc,
    recommendation: 'Implement Standard Contractual Clauses (SCCs) or obtain an adequacy decision for cross-border transfers.'
}) :-
    doc_fact(data_transfer_destination, Dest),
    doc_fact(transfer_safeguards, none),
    format(atom(Desc),
           'Data transfer to "~w" lacks adequate safeguards (SCCs, BCRs, or adequacy decision).',
           [Dest]).
