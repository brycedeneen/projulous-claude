# PJ for Service Providers: Comprehensive AI Assistant Capabilities

## Context

Today, PJ only helps **customers** -- finding providers, planning projects, diagnosing appliance issues. Service providers have **zero AI assistance** on the platform. This plan defines every capability PJ should have when talking to SPs, transforming PJ from a customer concierge into a full business partner for service providers.

The SP version of PJ should feel fundamentally different: **efficient, data-driven, action-oriented, and respectful of trade expertise**. PJ never explains plumbing to a plumber -- it focuses on the business side.

---

## How PJ Reaches SPs

### 1. Persistent Chat Panel
- Collapsible chat accessible from any SP page (web: bottom-right, mobile: floating button)
- Maintains conversation context across page navigation
- Conversation history grouped by topic

### 2. Contextual Inline Suggestions
- Small suggestion cards embedded in SP pages at relevant moments
- Example: On Offerings page -- "Your HVAC offering has no description. Want PJ to write one?"
- Non-blocking, dismissible, inline

### 3. Proactive Push Notifications
- Time-sensitive insights pushed via existing notification system
- Tapping opens PJ chat with context pre-loaded
- Weekly digest, urgent lead alerts, certification reminders

---

## Use Case Categories

### A. Onboarding & Setup (2 active, 3 deferred)

**A1. Voice-to-Form Onboarding** -- APPROVED
SP taps a mic button during onboarding and describes their business verbally. PJ uses speech-to-text + LLM extraction to pre-fill the onboarding form (business name, description, offering types, service area). The form remains the primary UI -- voice input is an alternative for SPs who prefer talking over typing. Requires speech-to-text integration (Web Speech API / Expo Speech).

**A2. "Polish with PJ" Description Enhancer** -- APPROVED
SP writes their description however they want (rough, minimal, bullet points, voice-to-text via mic button, etc.), then taps a "Polish with PJ" button below the textarea. PJ takes their raw input + SP context (offering types, service area, certification status) and rewrites it into a polished, professional description. SP can accept, edit further, and re-polish iteratively within the session until they're happy. No popover or extra questions -- just improves what they already wrote.

**A3. Offering Setup Advisor** -- DEFERRED (insufficient platform data)

**A4. Service Area Optimizer** -- DEFERRED (insufficient platform data)

**A5. Pricing Configuration Advisor** -- DEFERRED (insufficient platform data)

---

### B. Content Creation & Copywriting (6 use cases)

**B1. Offering Description Generator**
PJ writes compelling, SEO-friendly descriptions for each offering based on type, specialties, and service area. Better descriptions improve search ranking and customer conversion when SPs appear in PJ's find-service results.

**B2. Quote Response Drafter**
When an SP receives a QuoteRequest, PJ drafts a professional response including price breakdown, timeline, and next steps. PJ reads the chatSummary, understands the customer's problem, and produces a quote the SP reviews and sends. Speed and professionalism in responses directly affect conversion.

**B3. Customer Message Reply Drafter**
PJ suggests professional replies for SP messages in conversations. Reads conversation history, understands context, drafts a response the SP edits before sending. Adapts language to match the customer's preference (EN/ES/FR). Faster response times improve ratings.

**B4. Promotion Copy Writer**
PJ suggests promotion ideas based on seasonality, offering type, and market patterns. "March is great for spring promotions! For HVAC: 'Spring AC Tune-Up Special' -- $79 inspection before summer heat." Writes full promotion copy with title, description, terms, dates. *(Requires promotions feature)*

**B5. Showcase Project Writer**
PJ helps SPs write portfolio showcase posts by interviewing them about completed projects. "Tell me about the job -- what was the problem, what did you do, what was the result?" Generates a professional case study narrative. Showcase posts drive trust; most SPs won't write them without help. *(Requires showcase feature)*

**B6. Review Response Generator**
When SPs receive customer reviews, PJ drafts professional responses -- grateful for positive, empathetic and solution-oriented for negative. Consistent, professional review responses build brand trust. *(Requires review system)*

---

### C. Customer Communication & Lead Management (6 use cases)

**C1. Lead Prioritization & Auto-Triage**
When quote requests arrive, PJ automatically categorizes by urgency, complexity, location proximity, and estimated value. Presents prioritized action cards: "URGENT: Emergency water heater replacement, 3 miles away, highest value. The routine AC maintenance can wait." SPs waste time deciding which leads to handle first -- prioritization improves response time for high-value leads.

**C2. Automated Follow-Up Suggestions**
PJ tracks quote requests and conversations without responses and nudges the SP. "You quoted $450 for gutter cleaning 3 days ago but haven't heard back. Want me to draft a follow-up?" Also suggests post-job follow-ups for reviews/feedback. Many leads are lost to lack of follow-up.

**C3. Customer Project Briefing**
When an SP is added to a CustomerProject, PJ summarizes everything: scope, phases, budget estimates, other SPs involved, customer preferences, appliance details, conversation history. "You've been added to 'Kitchen Renovation'. Budget $15K-20K. Phase 3 (Plumbing) is yours, estimated 3 days." SPs currently get minimal context when added.

**C4. Multi-Language Communication Bridge**
PJ auto-translates messages between SPs and customers who speak different languages. English-speaking plumber receives Spanish customer's message in English, writes response in English, PJ translates to Spanish before sending. Breaks language barriers, expanding addressable market.

**C5. Batch Quote Responder**
When SP has multiple pending quote requests, PJ presents them in priority order and drafts responses for all in sequence. "You have 4 pending requests. Start with the emergency? I'll draft a response for each." Knock out the backlog efficiently.

**C6. After-Hours Auto-Responder**
PJ handles after-hours customer inquiries on behalf of the SP. For emergencies: "For gas emergencies, call 911 and your gas company immediately. We'll follow up first thing tomorrow." For routine: "Thanks for reaching out! We'll respond during business hours." Prevents lost leads and protects customer safety.

---

### D. Quote Generation & Pricing (4 use cases)

**D1. Intelligent Quote Builder**
PJ generates detailed, itemized quotes based on job type, customer description, and SP's historical pricing. "For a whole-house rewire in 2,000 sqft: labor $3,500-4,500, materials $2,000-2,800, permits $200-400. Total: $5,700-7,700." Professional line-item quotes win more business than vague estimates.

**D2. Competitive Pricing Insights**
PJ provides market pricing context using anonymized platform data. "The average AC tune-up in your area costs $120-180. Your price of $95 is below market -- you could increase 20-30% without losing competitiveness." Data-driven pricing improves revenue without market research.

**D3. Quote-from-Project Generator**
When reviewing a customer project, PJ generates a detailed estimate based on project phases, budget line items, and the SP's offering configurations. Pre-formats the quote text for easy copy/send.

**D4. Estimate-to-Invoice Converter**
After job completion, PJ converts the original quote into an invoice, adjusting for actual work. "Original quote: $350. Extra hour for old unit removal. Adjusted: $425. Generate invoice?" Streamlines billing cycle. *(Requires job invoice feature)*

---

### E. Scheduling & Availability (4 use cases)

**E1. Smart Scheduling Assistant**
PJ analyzes bookings, travel time, and service durations to optimize the SP's schedule. "You have a 2-hour gap between your 10am Aurora job and 3pm Lakewood job. I can fit a 1-hour call in that window. Suggest available slots to the pending customer?" Maximizes billable hours, reduces dead time. *(Requires scheduling feature)*

**E2. Seasonal Availability Planner**
PJ helps plan seasonal workload changes. "HVAC demand peaks June-August. Consider extending hours May-September and blocking vacation in April. Want me to set up summer business hours?" Prevents overbooking during peak and underutilization during slow periods.

**E3. Time-Off Impact Analyzer**
When SP plans time off, PJ analyzes the impact. "Dec 23-Jan 2 off affects 3 pending quotes and 1 confirmed booking. Want me to notify affected customers and suggest alternatives?" Prevents accidentally missing commitments.

**E4. Business Hours Optimizer**
PJ analyzes when quote requests arrive and suggests optimal hours. "Peak demand: Mon-Fri 7-9 AM and 5-8 PM (before/after work). Your current 8-5 hours miss the evening peak entirely. Providers with evening availability get 35% more requests."

---

### F. Analytics & Business Intelligence (7 use cases)

**F1. Performance Dashboard Narrator**
PJ provides natural-language weekly/monthly summaries. "This month: 12 quote requests (up 25%), 8 converted (67% rate), average value $340. Busiest day: Tuesday. HVAC gets 3x more requests than plumbing." Turns raw data into actionable insights.

**F2. Lead Source Attribution**
PJ tells SPs where leads come from. "60% from PJ's AI find-service, 25% from direct profile visits, 15% from project invites. You appeared in 45 searches but were selected in only 8 -- consider improving your description." Understanding sources helps invest in what works.

**F3. Response Time Analytics**
PJ tracks and benchmarks response times. "Your average: 4.2 hours. SPs who respond within 1 hour have 3x higher conversion. Want instant notifications for new leads?" Response time is the biggest predictor of lead conversion.

**F4. Seasonal Demand Forecasting**
PJ predicts upcoming demand by offering type, region, and historical patterns. "Snow removal typically spikes mid-November. SPs who pre-schedule marketing saw 2x more bookings last year. Start preparing now." Proactive intelligence for staffing and equipment.

**F5. Competitor Awareness Briefing**
Anonymized competitive insights. "Your area has 14 plumbing providers. 6 certified (including you). Average rating: 4.2 (yours: 4.8 -- top 15%). 3 Pinnacle, 4 Pro, 3 Starter, 4 Free. Your main gap: project count." Competitive awareness motivates improvement.

**F6. Revenue Forecasting**
PJ projects future revenue from pipeline data. "Confirmed bookings next month: $3,200. Pending quotes worth $2,800 at your 65% close rate. Expected: $5,000-5,400." Cash flow visibility is critical for small businesses.

**F7. Platform ROI Calculator**
PJ calculates return on Projulous membership. "Your PRO costs $X/month. This month: 12 leads, 8 converted, $4,200 revenue. Cost-per-lead: $X. ROI: 14x." Demonstrates value, reduces churn.

---

### G. Business Coaching & Optimization (6 use cases)

**G1. Profile Completeness Coach**
PJ scores profile completeness with specific, actionable recommendations. "65% complete. Missing: company description (-10 ranking points), phone (-5), website (-5). Completing all items could boost ranking 25%. Help with description first?"

**G2. Response Quality Scorer**
PJ scores SP's quote responses on professionalism, completeness, persuasiveness. SP submits: "We can do that. $500. Let me know." PJ: "3/10 conversion potential. Too brief, no personalization, no scheduling. Here's an 8/10 version..." Teaches SPs to write better.

**G3. Offering Optimization Advisor**
PJ identifies underperforming offerings and suggests changes. "Your Drain Cleaning offering has 45% conversion. Rewriting the description to match search terms could help. Your 15-mile radius misses 8 customers/month nearby. You don't list Water Treatment but demand is high in your area."

**G4. Membership Tier Upgrade Advisor**
PJ calculates ROI of upgrading based on actual data. "You're FREE with 8+ monthly requests. STARTER would unlock priority placement -- estimated 30% more leads. At your $350 average, that's ~$1,050/month extra revenue vs $X/month cost."

**G5. Weekly Business Digest**
Automated Monday morning summary. "Wins: 3 new projects (best week in 2 months!), 4.9 rating, 100% response rate. Needs Attention: 1 quote pending 3 days, certification expires in 28 days. Top Action: Respond to Tom R. -- emergency quotes unanswered 3+ days have 95% drop-off." Delivered via notification + PJ chat.

**G6. New Offering Recommender**
PJ identifies demand gaps. "High demand for home automation in your area but only 1 provider. As an electrician, adding HOME_AUTOMATION could capture these leads." Helps SPs diversify based on actual market demand.

---

### H. Certification & Compliance (4 use cases)

**H1. Certification Preparation Assistant**
PJ walks SPs through verification questions in advance. "Certification asks about licensing, insurance, bonding, references. Let me help prepare your docs. Do you have a valid contractor's license?" Higher pass rates = more verified SPs = better platform quality.

**H2. License & Certification Expiry Tracker**
PJ monitors expiry dates and proactively alerts. "Certification expires in 45 days. Recertification requires updated insurance. Want me to start renewal?" Also tracks external license/insurance expiry if SP provides dates. Prevents accidental lapses.

**H3. Certification Status Explainer**
PJ explains where the SP is in the process. "Currently 'Under Review'. 8 of 10 questions answered. 2 pending admin review. Expected decision: 3-5 business days." Transparency reduces anxiety and support tickets.

**H4. State Compliance Checklist**
PJ provides state-specific licensing and insurance requirements by offering type. "To operate as an electrician in Colorado: Master Electrician License, $1M liability insurance, Workers' Comp if 2+ employees. Your profile is missing Workers' Comp documentation." *(Requires compliance data)*

---

### I. Team Management (4 use cases)

**I1. Team Scheduling Coordinator**
PJ helps assign bookings to team members based on skills, availability, location. "John is available Tuesday 9am-12pm, specializes in water heater installs, closest to the job site. Assign him?" Reduces scheduling conflicts and travel time. *(Depends on scheduling feature)*

**I2. Team Performance Insights**
PJ provides team-level analytics. "This month: John completed 10 jobs (avg 4.8 rating), Sarah 9 (4.6), Mike 5 (4.2). Mike has longest average duration -- may benefit from training." Data-driven team management.

**I3. New Team Member Onboarding Guide**
When a new member accepts an invite, PJ provides personalized onboarding. "Welcome to ABC Plumbing! Your hours: Mon-Fri 8-5. You'll receive booking assignments via notification. Here's how to update availability." Reduces admin's training burden.

**I4. AI-Powered Multi-Truck Dispatch**
For larger operations, PJ optimizes daily dispatch across team members considering skills, location, equipment, and customer preferences. "John starts with AC install in Aurora (needs refrigerant cert), Sarah handles 3 calls in central Denver, Mike does evening callback in Lakewood." *(Advanced -- requires route optimization)*

---

### J. Project & Job Management (4 use cases)

**J1. Job Completion Notes Assistant**
SP speaks casually ("Fixed the leak, replaced the P-trap, noticed corroding shutoff valve") and PJ structures it into formal documentation. Proper records protect legally and give customers clear records.

**J2. Materials & Parts Estimator**
PJ estimates materials for a job based on customer description. "Kitchen sink replacement: new sink, faucet set, P-trap kit, supply lines, putty, Teflon tape. Materials: $180-$350 depending on quality." Accurate estimates lead to better quotes.

**J3. Warranty Tracker**
PJ tracks warranties on work performed. "You installed a water heater for the Johnsons 11 months ago. Manufacturer warranty: 6 years parts. Your labor warranty expires in 1 month. Send reminder about extension?" Creates upsell opportunities. *(Requires warranty entity)*

**J4. Job Photo Documentation**
SP takes before/during/after photos. PJ auto-tags, organizes by job, creates visual summary. "12 photos from bathroom remodel organized: Before (4), During (3), After (5)." Visual docs serve as portfolio, warranty evidence, and deliverables.

---

### K. Customer Relationship Management (3 use cases)

**K1. Customer Interaction History Summary**
PJ provides complete history for any customer. "3 jobs for the Martinez family: gutter cleaning ($250, March), AC tune-up ($150, June), furnace inspection ($120, Oct). Lifetime value: $520. Last service: 5 months ago." Enables personalized service.

**K2. Re-Engagement Campaign Suggestions**
PJ identifies dormant customers and suggests outreach. "12 past customers haven't booked in 6+ months. 5 had AC services -- with summer approaching, send maintenance reminders?" Repeat customers are most profitable.

**K3. Customer Satisfaction Predictor**
PJ analyzes conversation tone, timing, and job details to flag risk. "Johnson booking has risk factors: customer mentioned higher-than-expected price, job ran 45 min over estimate. Consider a follow-up call." Proactive risk detection prevents negative reviews.

---

### L. Emergency & Urgent Response (2 use cases)

**L1. Urgent Lead Alert & Auto-Response**
When a customer marks EMERGENCY urgency, PJ immediately alerts matching SPs and can auto-confirm availability. "URGENT: Burst pipe, 3 miles away, you're available now. Confirm availability and send ETA?" Emergency jobs are high-margin; speed is everything.

**L2. Emergency Safety Routing**
For dangerous situations (gas leaks, electrical fires), PJ provides immediate safety guidance before connecting to the SP. "Gas smell reported. PJ told the customer to call 911 and the gas company first. Customer is safe and waiting for your follow-up."

---

### M. Knowledge & Training (3 use cases)

**M1. On-Demand Industry Knowledge Base**
PJ as a reference tool on job sites. "What's the code requirement for GFCI outlets in bathrooms in Colorado?" or "Recommended maintenance interval for tankless water heaters?" Quick reference saves time and positions Projulous as an essential tool.

**M2. Regulatory Change Alerts**
PJ monitors relevant regulatory changes. "New Colorado energy efficiency standards take effect July 1. HVAC installations must now include minimum SEER2 rating of 15. This affects your AC installation offering." *(Requires external data feeds)*

**M3. Technical Diagnostic Partner**
Like customer appliance diagnostics but more technical. "Carrier Infinity furnace: 3-blink error code indicates pressure switch fault. Check exhaust vent blockage, condensate drain, and inducer motor." Reduces diagnostic time for less experienced technicians.

---

### N. Platform Support & Administration (4 use cases)

**N1. PJ as SP Support Agent**
PJ answers platform questions conversationally. "How do I update my business hours?" "How does certification work?" "What are PRO benefits?" Replaces static help articles with instant, contextual support.

**N2. Billing Explainer**
PJ explains billing details. "Next invoice: $X due March 15. PRO membership for March. 1 outstanding invoice from February. Want help updating payment method?" Reduces billing-related support tickets.

**N3. Support Ticket Filing Assistant**
PJ gathers issue details conversationally, then creates a pre-filled support ticket. "Charged twice this month? I'll file ticket #1234 with priority HIGH. Your plan: PRO, last charges: $X on Feb 1, $X on Feb 15. Expected response: 24 hours."

**N4. Data Export Helper**
PJ helps SPs export business data for taxes, reporting, or migration. "Available: all projects with dates/amounts, quote history, monthly revenue summary. For tax purposes, I'd recommend projects + revenue summary. Format: CSV or PDF?"

---

### O. Advanced & Aspirational (3 use cases)

**O1. Voice Command Interface**
Hands-free PJ for job sites via speech-to-text. "PJ, mark the Johnson job complete and note: replaced main shutoff valve, 3/4 inch brass." Essential for tradespeople working with tools. *(Requires speech-to-text integration)*

**O2. Smart Promotion Timing**
PJ identifies optimal windows for promotions based on demand patterns, competitor activity, and the SP's capacity. "Demand for AC tune-ups peaks in 3 weeks. You have 40% schedule availability. Running a promotion now would fill those slots before competitors." *(Requires promotions + scheduling)*

**O3. Automated Customer Review Requests**
After booking completion, PJ automatically sends a personalized review request at the optimal time (24-48 hours post-service). "Hi Sarah, hope the AC is running great! If you have a moment, we'd really appreciate a review." Timing and personalization improve review rates. *(Requires review system)*

---

## Summary: 56 Use Cases Across 15 Categories

| Category | Count | Quick Wins (No New Features) | Needs New Feature |
|----------|-------|------------------------------|-------------------|
| A. Onboarding & Setup | 5 | 3 | 2 |
| B. Content Creation | 6 | 3 | 3 |
| C. Customer Communication | 6 | 4 | 2 |
| D. Quoting & Pricing | 4 | 2 | 2 |
| E. Scheduling | 4 | 1 | 3 |
| F. Analytics | 7 | 5 | 2 |
| G. Coaching | 6 | 6 | 0 |
| H. Certification | 4 | 3 | 1 |
| I. Team Management | 4 | 2 | 2 |
| J. Project/Job Mgmt | 4 | 1 | 3 |
| K. CRM | 3 | 2 | 1 |
| L. Emergency Response | 2 | 1 | 1 |
| M. Knowledge & Training | 3 | 1 | 2 |
| N. Platform Support | 4 | 4 | 0 |
| O. Advanced | 3 | 0 | 3 |
| **Total** | **56** | **38** | **18** |

### Top 15 Quick Wins (Buildable on existing entities/APIs)

These require no new entities and have existing backend support:

1. **B1** Offering Description Generator -- just LLM + existing offering data
2. **B2** Quote Response Drafter -- QuoteRequest with chatSummary exists
3. **B3** Customer Message Reply Drafter -- conversation messages exist
4. **G1** Profile Completeness Coach -- SpDataEnrichmentService exists
5. **G2** Response Quality Scorer -- conversation messages exist
6. **G5** Weekly Business Digest -- all aggregation data exists
7. **H1** Certification Prep Assistant -- verification questions + AI review exist
8. **H3** Certification Status Explainer -- all cert data/logs exist
9. **N1** PJ as SP Support Agent -- help center + support conversations exist
10. **N2** Billing Explainer -- billing account/invoices exist
11. **F1** Performance Dashboard Narrator -- project/quote data exists
12. **F3** Response Time Analytics -- message timestamps exist
13. **C3** Customer Project Briefing -- all project/phase data exists
14. **K1** Customer Interaction History -- all linking entities exist
15. **A2** Business Description Writer -- just LLM + SP profile data

---

## Technical Architecture (High Level)

### New Conversation Types
- `SP_BUSINESS_ASSISTANT` -- General SP questions, business advice
- `SP_CONTENT_WRITER` -- Writing assistance (descriptions, quotes, responses)
- `SP_QUOTE_ASSISTANT` -- Quote drafting and lead management
- `SP_BUSINESS_ANALYTICS` -- Analytics and insights

### New Backend Services
- `SpChatService` -- Routes SP conversations (mirrors ChatService)
- `SpContentWriterService` -- Content generation prompts
- `SpBusinessIntelligenceService` -- Analytics aggregation
- `SpToolRegistry` -- SP-specific tools for Gemini agent
- `SpDigestCronService` -- Weekly digest generation

### New Prompt Templates (15+)
- SP system prompt (business partner persona)
- Offering description writer
- Quote response drafter
- Customer message drafter
- Profile bio generator
- Business summary narrator
- Pricing analyst
- Certification helper
- Response quality coach
- And more per capability

### Frontend Components
- `SPPJChatPanel` -- Persistent floating chat for all SP pages
- `PJSuggestionCard` -- Inline contextual suggestions
- `PJInsightCard` -- Dashboard insight cards
- `PJDraftReview` -- Content review/edit before sending

### SP PJ Chat Entry Point
- REST: `POST /v1/sp-ai/chat`
- Guards: AccessTokenGuard + SP team role verification
- Permission: `SP_AI_ASSISTANT_ACCESS`
