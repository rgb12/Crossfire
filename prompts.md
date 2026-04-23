#1 Learn how to program first: AI is a multiplier of your existing knowledge. You must understand the fundamentals to get useful results, as you cannot outsource your thinking if you don't have the foundation.

#2 Be as specific as humanly possible: Provide full technical details, including your exact tech stack, terminal commands, and specific documentation, to prevent the AI from guessing and producing "catfish" code.

#3 Leverage external resources: Don't just rely on the AI's internal knowledge; find relevant documentation or LLM-formatted pages (LLMs.txt) and provide them to the AI to ensure it uses the most accurate information.

#4 Break big tasks into smaller tasks: AI handles small, granular tasks much better than large, complex ones. If you can't break a task down, you likely don't understand the problem well enough yet.

#5 Do not let the AI do all the thinking: You should be okay with letting AI type for you, but you must remain responsible for the logic and architecture to ensure you remain a useful developer.

#6 Use a "Do Not" section: Explicitly list what the AI should not touch or change in your codebase. This helps reduce "slop" and prevents the AI from modifying unrelated parts of your project.

#7 Use project-specific memory files: Create a guidelines.md or agent.md file containing your tech stack, project overview, and important commands so the AI has consistent context.

#8 Extend AI with Model Context Protocol (MCP): Use MCP tools to allow the AI to fetch live documentation, access Chrome developer tools, and analyze project logs automatically.

#9 Give the AI a way to verify its work: Never let AI just write code; provide it with tests, CLI commands, or CI/CD pipelines so it can prove the code works before you accept it.



I would like to implement a feature into my DCS mission: Strategic Airlift Operation

CH47 and C130J
FROM/TO Airbase/FARP transport troops/crates/vehicles

Should test with Dynamic Cargo for CH47

Once the operation initiated, the user must load using CTLD
A list of random troops/crates/vehicles will be generated compatible for both aircraft, from the CTLD parts list

Make sure helicopters have shorter flight times, compared to C130.

The operation manager will check if crates/statics/vehicles (all part of CTLD) are present at the arrival zone, once completed remove them (these crates/statics/vehicles should not be tracked by CTLD and persistence).

Improve the above if you think its necessary for easier integration into the codebase and for performance.
Help me plan for an implementation, give questions if you have also potential good improvements