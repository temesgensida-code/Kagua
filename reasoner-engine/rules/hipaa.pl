%% ============================================================================
%% HIPAA — Health Insurance Portability and Accountability Act
%%
%% check_violation/2 rules for healthcare data privacy compliance.
%% ============================================================================

:- module(hipaa, [check_violation/2]).

%% Local wrapper so unqualified doc_fact/2 calls resolve to user:doc_fact/2
doc_fact(K, V) :- user:doc_fact(K, V).

%% ---------------------------------------------------------------------------
%% § 164.312(a)(1) — Access Control
%% Covered entities must implement technical access controls for ePHI.
%% ---------------------------------------------------------------------------
check_violation(hipaa, violation{
    rule:    'HIPAA § 164.312(a)(1)',
    title:   'Insufficient Access Controls for ePHI',
    severity: critical,
    description: 'No role-based access control is defined for electronic Protected Health Information.',
    recommendation: 'Implement RBAC with unique user authentication and automatic session logoff for all ePHI systems.'
}) :-
    doc_fact(contains_phi, true),
    doc_fact(access_control, none).

check_violation(hipaa, violation{
    rule:    'HIPAA § 164.312(a)(1)',
    title:   'Missing Access Control Policy',
    severity: warning,
    description: 'Document references PHI but lacks an access control policy specification.',
    recommendation: 'Define explicit access control policies including user provisioning, de-provisioning, and periodic access reviews.'
}) :-
    doc_fact(contains_phi, true),
    \+ doc_fact(access_control, _).

%% ---------------------------------------------------------------------------
%% § 164.312(e)(1) — Transmission Security
%% ePHI in transit must be encrypted.
%% ---------------------------------------------------------------------------
check_violation(hipaa, violation{
    rule:    'HIPAA § 164.312(e)(1)',
    title:   'Unencrypted PHI Transmission',
    severity: critical,
    description: 'Protected Health Information may be transmitted without encryption.',
    recommendation: 'Enforce TLS 1.2+ for all ePHI transmissions; prohibit unencrypted email or FTP for PHI.'
}) :-
    doc_fact(contains_phi, true),
    doc_fact(transmission_encrypted, false).

%% ---------------------------------------------------------------------------
%% § 164.530(c) — Safeguards for PHI
%% Administrative, technical, and physical safeguards must be in place.
%% ---------------------------------------------------------------------------
check_violation(hipaa, violation{
    rule:    'HIPAA § 164.530(c)',
    title:   'Inadequate PHI Safeguards',
    severity: warning,
    description: 'Document mentions PHI handling but does not specify administrative, technical, or physical safeguards.',
    recommendation: 'Document all three categories of safeguards: administrative policies, technical controls, and physical security measures.'
}) :-
    doc_fact(contains_phi, true),
    \+ doc_fact(safeguards_documented, true).

%% ---------------------------------------------------------------------------
%% § 164.502(a) — Minimum Necessary Standard
%% Use and disclosure of PHI should be limited to the minimum necessary.
%% ---------------------------------------------------------------------------
check_violation(hipaa, violation{
    rule:    'HIPAA § 164.502(a)',
    title:   'Minimum Necessary Principle Not Applied',
    severity: warning,
    description: 'Document grants broad access to PHI without applying the minimum necessary standard.',
    recommendation: 'Limit PHI access to the minimum amount needed for each role or function.'
}) :-
    doc_fact(contains_phi, true),
    doc_fact(broad_phi_access, true).

%% ---------------------------------------------------------------------------
%% § 164.308(a)(6) — Security Incident Procedures
%% Covered entities must have incident response plans.
%% ---------------------------------------------------------------------------
check_violation(hipaa, violation{
    rule:    'HIPAA § 164.308(a)(6)',
    title:   'No Security Incident Response Plan',
    severity: critical,
    description: 'No security incident response procedure is documented for PHI breaches.',
    recommendation: 'Develop and maintain a security incident response plan that includes breach identification, containment, notification, and remediation.'
}) :-
    doc_fact(contains_phi, true),
    \+ doc_fact(incident_response_plan, true).

%% ---------------------------------------------------------------------------
%% Business Associate Agreement (BAA) Requirements
%% Third-party handlers of PHI must have a signed BAA.
%% ---------------------------------------------------------------------------
check_violation(hipaa, violation{
    rule:    'HIPAA BAA Requirement',
    title:   'Missing Business Associate Agreement',
    severity: critical,
    description: 'Third-party vendor handles PHI but no Business Associate Agreement is referenced.',
    recommendation: 'Execute a HIPAA-compliant BAA with all third-party vendors who access, store, or transmit PHI.'
}) :-
    doc_fact(contains_phi, true),
    doc_fact(third_party_handles_phi, true),
    \+ doc_fact(baa_signed, true).
