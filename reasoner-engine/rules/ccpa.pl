%% ============================================================================
%% CCPA — California Consumer Privacy Act
%%
%% check_violation/2 rules for CCPA consumer data privacy compliance.
%% ============================================================================

:- module(ccpa, [check_violation/2]).

%% Local wrapper so unqualified doc_fact/2 calls resolve to user:doc_fact/2
doc_fact(K, V) :- user:doc_fact(K, V).

%% ---------------------------------------------------------------------------
%% § 1798.100 — Right to Know
%% Consumers have the right to know what personal information is collected.
%% ---------------------------------------------------------------------------
check_violation(ccpa, violation{
    rule:    'CCPA § 1798.100',
    title:   'No Data Collection Disclosure',
    severity: critical,
    description: 'Document does not disclose what categories of personal information are collected.',
    recommendation: 'Include a comprehensive list of data categories collected and their business purposes.'
}) :-
    \+ doc_fact(data_collection_disclosed, true).

%% ---------------------------------------------------------------------------
%% § 1798.105 — Right to Delete
%% Consumers can request deletion of their personal information.
%% ---------------------------------------------------------------------------
check_violation(ccpa, violation{
    rule:    'CCPA § 1798.105',
    title:   'No Deletion Request Mechanism',
    severity: warning,
    description: 'No consumer data deletion request mechanism is documented.',
    recommendation: 'Provide a clear and accessible mechanism for consumers to submit data deletion requests.'
}) :-
    \+ doc_fact(deletion_mechanism, true).

%% ---------------------------------------------------------------------------
%% § 1798.120 — Right to Opt Out of Sale
%% Consumers can opt out of the sale of their personal information.
%% ---------------------------------------------------------------------------
check_violation(ccpa, violation{
    rule:    'CCPA § 1798.120',
    title:   'No Opt-Out for Data Sale',
    severity: critical,
    description: 'Personal data is sold to third parties but no opt-out mechanism is provided.',
    recommendation: 'Add a "Do Not Sell My Personal Information" link and opt-out process.'
}) :-
    doc_fact(sells_data, true),
    \+ doc_fact(opt_out_mechanism, true).

%% ---------------------------------------------------------------------------
%% § 1798.135 — Opt-Out Link Requirement
%% Website must include a "Do Not Sell" link if data is sold.
%% ---------------------------------------------------------------------------
check_violation(ccpa, violation{
    rule:    'CCPA § 1798.135',
    title:   'Missing Do-Not-Sell Link',
    severity: warning,
    description: 'Website or service sells data but does not provide the required "Do Not Sell My Personal Information" link.',
    recommendation: 'Add a clearly visible "Do Not Sell My Personal Information" link on the homepage.'
}) :-
    doc_fact(sells_data, true),
    \+ doc_fact(do_not_sell_link, true).

%% ---------------------------------------------------------------------------
%% § 1798.150 — Data Breach Liability
%% Consumers may bring civil action for data breaches due to negligence.
%% ---------------------------------------------------------------------------
check_violation(ccpa, violation{
    rule:    'CCPA § 1798.150',
    title:   'Inadequate Data Security Measures',
    severity: critical,
    description: 'Document lacks specification of reasonable security measures for personal information.',
    recommendation: 'Implement and document reasonable security procedures including encryption, access controls, and monitoring.'
}) :-
    doc_fact(collects_pi, true),
    \+ doc_fact(security_measures_documented, true).

%% ---------------------------------------------------------------------------
%% Minor Data Protection (Under 16)
%% ---------------------------------------------------------------------------
check_violation(ccpa, violation{
    rule:    'CCPA Minor Data Protection',
    title:   'No Parental Consent for Minors Under 13',
    severity: critical,
    description: 'Service may collect data from minors under 13 without verifiable parental consent.',
    recommendation: 'Implement age verification and obtain verifiable parental consent before collecting data from children under 13.'
}) :-
    doc_fact(collects_minor_data, true),
    \+ doc_fact(parental_consent_mechanism, true).
