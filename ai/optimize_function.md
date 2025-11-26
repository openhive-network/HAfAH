---
description: Optimize a function. User provides a function name and a list of arguments. User may also suggest an optimization method.
---

1. Run a cold_start workflow on the remote server.
2. Follow the steps in the explain_function.md workflow.
3. Optimize the function based on the explain analyze results and/or the user's suggestions. Do not add any index that would be over 10GB in size. Write a brief description of the optimization attempt to the chat window.
4. Run a cold_start workflow on the remote server.
5. Run explain without analyze on the optimized query using explain_query.md workflow. If the explain results suggest the query will be faster than the original query, run explain analyze afterwards to verify it.
6. If the explain analyze results are not satisfactory, repeat steps 2 and 3 or give up if problem seems too hard.
7. If the explain analyze results are satisfactory, return the optimized function.