# LinkedIn post draft

I built a small tool for the part of social-media work that usually gets skipped: checking whether a trend is actually ready to become a post.

SignalBrief takes a JSON/CSV snapshot, then:

- checks freshness and duplicate records
- requires an evidence URL
- flags risky claims and unchecked rights
- scores audience fit, novelty and safety
- creates a short brief only when the item is ready
- sends everything else to a human-review queue

It runs locally with Node.js. There is no platform login, scraping, live account data or auto-publishing. The examples use synthetic data.

The repository includes the dashboard, CLI audit, n8n-compatible starter workflow, tests, and a 50-second walkthrough made from real local-run outputs:

https://github.com/Shivam9864op/signalbrief-trend-qa

Personal open-source demo. Not client work or a production claim.

What check would you add before a content brief is approved?

#WorkflowQA #SocialMediaOperations #NodeJS #Automation #HumanInTheLoop
