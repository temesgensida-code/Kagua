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
    id: 'ethiopian_labour_proclamation',
    name: 'Labour Proclamation 1156/2019',
    color: '#00f0ff',
    bg: 'rgba(0, 240, 255, 0.12)',
    border: 'rgba(0, 240, 255, 0.5)',
    glow: '0 0 12px rgba(0, 240, 255, 0.3)',
    active: true,
    description: 'Federal Democratic Republic of Ethiopia Labour Proclamation No. 1156/2019',
    ruleCount: 14
  },
  {
    id: 'eth_probation',
    name: 'Article 11 Probation',
    color: '#ffd700',
    bg: 'rgba(255, 215, 0, 0.12)',
    border: 'rgba(255, 215, 0, 0.5)',
    glow: '0 0 12px rgba(255, 215, 0, 0.3)',
    active: true,
    description: 'Probation period statutory limit (Max 60 working days per Art. 11(3))',
    ruleCount: 1
  },
  {
    id: 'eth_working_hours',
    name: 'Article 61 & 67 Working Hours',
    color: '#00ff88',
    bg: 'rgba(0, 255, 136, 0.12)',
    border: 'rgba(0, 255, 136, 0.5)',
    glow: '0 0 12px rgba(0, 255, 136, 0.3)',
    active: true,
    description: 'Normal working hours cap (8 hrs/day, 48 hrs/wk) & overtime cap (2 hrs/day)',
    ruleCount: 3
  },
  {
    id: 'eth_maternity',
    name: 'Article 88 Maternity Leave',
    color: '#ff528c',
    bg: 'rgba(255, 82, 140, 0.12)',
    border: 'rgba(255, 82, 140, 0.5)',
    glow: '0 0 12px rgba(255, 82, 140, 0.3)',
    active: true,
    description: 'Paid maternity leave statutory entitlement (120 consecutive days)',
    ruleCount: 1
  },
  {
    id: 'eth_harassment',
    name: 'Article 14 Workplace Protections',
    color: '#d070ff',
    bg: 'rgba(208, 112, 255, 0.12)',
    border: 'rgba(208, 112, 255, 0.5)',
    glow: '0 0 12px rgba(208, 112, 255, 0.3)',
    active: true,
    description: 'Anti-discrimination and zero-tolerance sexual harassment policy mandates',
    ruleCount: 2
  },
  {
    id: 'eth_severance',
    name: 'Article 39 Severance Pay',
    color: '#ffaa00',
    bg: 'rgba(255, 170, 0, 0.12)',
    border: 'rgba(255, 170, 0, 0.5)',
    glow: '0 0 12px rgba(255, 170, 0, 0.3)',
    active: true,
    description: 'Severance compensation terms for lawful contract termination',
    ruleCount: 1
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
    id: 'eth_employment_contract',
    filename: 'Ethiopia_Standard_Employment_Contract.pdf',
    size: '1.2 MB',
    type: 'PDF',
    content: `EMPLOYMENT CONTRACT UNDER ETHIOPIAN LABOUR LAW

1. PROBATION PERIOD
The employee shall be subject to a probation period of 90 working days starting from the date of commencement.

2. WORKING HOURS & OVERTIME
Normal working hours shall be 9 hours per day (45 hours per week). Overtime work may be requested up to 3 hours per day.

3. LEAVE ENTITLEMENTS
The employee is entitled to 12 working days of annual leave. Maternity leave shall consist of 60 consecutive days with full pay. Sick leave up to 3 months is permitted with medical certification.

4. TERMINATION NOTICE
Either party may terminate this agreement by providing 15 days written notice.`,
    complianceScore: 35,
    findings: [
      {
        framework: 'Ethiopian Labour Proclamation No. 1156/2019',
        severity: 'CRITICAL',
        title: 'Article 11(3) - Excessive Probation Period',
        description: 'Specified probation period of 90 working days exceeds statutory limit of 60 working days.',
        recommendation: 'Reduce probation period to max 60 working days per Article 11(3).'
      },
      {
        framework: 'Ethiopian Labour Proclamation No. 1156/2019',
        severity: 'CRITICAL',
        title: 'Article 88(2-3) - Insufficient Maternity Leave',
        description: 'Maternity leave of 60 days is below mandatory 120 consecutive days entitlement.',
        recommendation: 'Grant 120 consecutive days paid maternity leave (30 prenatal + 90 postnatal).'
      },
      {
        framework: 'Ethiopian Labour Proclamation No. 1156/2019',
        severity: 'CRITICAL',
        title: 'Article 61(1) - Excessive Daily Working Hours',
        description: 'Daily working hours (9 hrs) exceed statutory maximum of 8 hours per day.',
        recommendation: 'Cap normal daily working hours at 8 hours per day.'
      }
    ]
  },
  {
    id: 'eth_tech_contract',
    filename: 'Addis_Tech_Senior_Developer_Agreement.docx',
    size: '850 KB',
    type: 'DOCX',
    content: `ADDIS ABABA SOFTWARE INDUSTRY EMPLOYMENT CONTRACT

Section 1. Terms of Service & Probation
The trial probation period shall be 60 working days.

Section 2. Daily Hours
Working hours are 8 hours per day from Monday to Friday (40 hours per week).

Section 3. Annual & Sick Leave
Employee receives 16 working days of paid annual leave for the first year of service. Sick leave is granted up to 6 months per Article 85.

Section 4. Sexual Harassment & Non-Discrimination
Company maintains a zero-tolerance policy against sexual harassment and discrimination based on gender, religion, or HIV status per Article 14.`,
    complianceScore: 100,
    findings: [
      {
        framework: 'Ethiopian Labour Proclamation No. 1156/2019',
        severity: 'PASS',
        title: 'Full Proclamation No. 1156/2019 Compliance',
        description: 'All statutory clauses (Probation, Working Hours, Annual Leave, Sick Leave, Harassment Protections) fully comply with Ethiopian Labour Law.',
        recommendation: 'Maintain compliance records and annual policy review.'
      }
    ]
  }
];
