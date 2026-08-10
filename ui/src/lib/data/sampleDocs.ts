export interface Framework {
  id: string;
  name: string;
  color: string;
  bg: string;
  border: string;
  glow: string;
  active: boolean;
  description: string;
  ruleCount: number;
}

export const INITIAL_FRAMEWORKS: Framework[] = [
  {
    id: 'gdpr',
    name: 'GDPR',
    color: '#00e5ff',
    bg: 'rgba(0, 229, 255, 0.12)',
    border: 'rgba(0, 229, 255, 0.5)',
    glow: '0 0 12px rgba(0, 229, 255, 0.3)',
    active: true,
    description: 'General Data Protection Regulation (EU 2016/679)',
    ruleCount: 99
  },
  {
    id: 'hipaa',
    name: 'HIPAA',
    color: '#ff528c',
    bg: 'rgba(255, 82, 140, 0.12)',
    border: 'rgba(255, 82, 140, 0.5)',
    glow: '0 0 12px rgba(255, 82, 140, 0.3)',
    active: true,
    description: 'Health Insurance Portability and Accountability Act',
    ruleCount: 54
  },
  {
    id: 'sox',
    name: 'SOX',
    color: '#ffd700',
    bg: 'rgba(255, 215, 0, 0.12)',
    border: 'rgba(255, 215, 0, 0.5)',
    glow: '0 0 12px rgba(255, 215, 0, 0.3)',
    active: true,
    description: 'Sarbanes-Oxley Act for Corporate Financial Integrity',
    ruleCount: 42
  },
  {
    id: 'iso27001',
    name: 'ISO 27001',
    color: '#00ff88',
    bg: 'rgba(0, 255, 136, 0.12)',
    border: 'rgba(0, 255, 136, 0.5)',
    glow: '0 0 12px rgba(0, 255, 136, 0.3)',
    active: true,
    description: 'Information Security Management System Standard',
    ruleCount: 114
  },
  {
    id: 'ccpa',
    name: 'CCPA',
    color: '#d070ff',
    bg: 'rgba(208, 112, 255, 0.12)',
    border: 'rgba(208, 112, 255, 0.5)',
    glow: '0 0 12px rgba(208, 112, 255, 0.3)',
    active: true,
    description: 'California Consumer Privacy Act',
    ruleCount: 38
  },
  {
    id: 'pci-dss',
    name: 'PCI-DSS',
    color: '#ffaa00',
    bg: 'rgba(255, 170, 0, 0.12)',
    border: 'rgba(255, 170, 0, 0.5)',
    glow: '0 0 12px rgba(255, 170, 0, 0.3)',
    active: true,
    description: 'Payment Card Industry Data Security Standard',
    ruleCount: 78
  }
];

export interface SampleDoc {
  id: string;
  filename: string;
  size: string;
  type: string;
  content: string;
  complianceScore: number;
  findings: Array<{
    framework: string;
    severity: 'CRITICAL' | 'WARNING' | 'PASS';
    title: string;
    description: string;
    recommendation: string;
  }>;
}

export const SAMPLE_DOCS: SampleDoc[] = [
  {
    id: 'nda',
    filename: 'Master_Service_Agreement_v4.2.pdf',
    size: '1.4 MB',
    type: 'PDF',
    content: `MASTER SERVICE & CONFIDENTIALITY AGREEMENT... Section 4. Data Storage: Party B agrees to store all end-user metrics for an indefinite period on non-encrypted cold storage backups...`,
    complianceScore: 92,
    findings: [
      {
        framework: 'GDPR',
        severity: 'WARNING',
        title: 'Article 5(1)(e) - Data Storage Limitation',
        description: 'Indefinite data retention clause detected in Section 4 without defined expiry schedule.',
        recommendation: 'Specify explicit retention periods (e.g. 24 months) and automated deletion workflow.'
      },
      {
        framework: 'ISO 27001',
        severity: 'CRITICAL',
        title: 'Control A.10.1.1 - Policy on Use of Cryptographic Controls',
        description: 'Unencrypted storage specified for end-user metrics.',
        recommendation: 'Enforce AES-256 encryption at rest for all stored metrics and backup archives.'
      },
      {
        framework: 'HIPAA',
        severity: 'PASS',
        title: '§ 164.312(a)(1) - Access Control',
        description: 'Role-based access restrictions compliant with HIPAA administrative safeguards.',
        recommendation: 'Maintain quarterly audit logs.'
      }
    ]
  },
  {
    id: 'privacy',
    filename: 'Global_Privacy_Policy_2026.md',
    size: '480 KB',
    type: 'MD',
    content: `# Global Privacy Policy... We collect IP addresses, device identifiers, and geolocation data. Users in California and the EU may request data export via email to privacy@company.com...`,
    complianceScore: 97,
    findings: [
      {
        framework: 'CCPA',
        severity: 'PASS',
        title: 'Section 1798.100 - Consumer Right to Know',
        description: 'Explicit data collection notice and opt-out mechanisms provided.',
        recommendation: 'Verify automated web form endpoint response SLA < 45 days.'
      },
      {
        framework: 'GDPR',
        severity: 'WARNING',
        title: 'Article 13 - Right to Data Portability',
        description: 'Manual email request mechanism may bottleneck high-volume DSAR requests.',
        recommendation: 'Implement automated self-service data export portal.'
      }
    ]
  },
  {
    id: 'pci',
    filename: 'Payment_Gateway_Architecture_SOP.docx',
    size: '3.2 MB',
    type: 'DOCX',
    content: `PAYMENT INFRASTRUCTURE REGULATORY SOP... Primary cardholder account numbers (PAN) are logged in debug trace buffers during gateway timeout fallbacks...`,
    complianceScore: 78,
    findings: [
      {
        framework: 'PCI-DSS',
        severity: 'CRITICAL',
        title: 'Requirement 3.3 - PAN Masking and Storage',
        description: 'Plaintext Primary Account Number (PAN) logging detected in debug trace fallback buffers.',
        recommendation: 'Implement immediate regex masking filter for credit card patterns in system loggers.'
      },
      {
        framework: 'SOX',
        severity: 'WARNING',
        title: 'Section 404 - Internal Control Assessment',
        description: 'Trace buffer access lacks multi-party audit logging.',
        recommendation: 'Restrict trace logs to L3 security engineers with mandatory audit trailing.'
      }
    ]
  }
];
