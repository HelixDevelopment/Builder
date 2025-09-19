# TODOs

- For each category create debate AI group
  - Each coder group shall contain of one coder and one regular model of same model family, for example qwen + qwen-coder
  - Expose the debate group via Ollama for API access

## For later

- Make sure that our scripts present its work like qwen code cli: [https://github.com/QwenLM/qwen-code](https://github.com/QwenLM/qwen-code)
- Patch Ollama Gemini with changes we want - visual, functional, etc
- Enable Goose worker

## In progress

- Integrate RAG with Fixers to pickup from out memory database
- Fixers: Support for Goose
- Fixers: Auto detection between AI CLIs sorted by priority - claude, goose, qwen, etc
- Web UI for tasks with APIs (instead of manual editing). After we create or edit task submit with confirmation sends it to execution to the AI
- Recipes for adding more tests (each test scenario is defined by the recipe)

## Completed

- FIXME: Audio model for 7B does not exist on Ollama [Claude]
- Make sure that every model before it is installed is checked if exists in Ollama, as fallback pull it and apply from Hugging Face [Claude]
- TASK: [003 Testing Scripts](../AITasks/Tasks/003%20Testing%20Scripts/TASK.md) [Claude]
- FIXME:

  ```bash
   ✘ python3 Scripts/AudioTemplates/text_to_speech.py 'Hello, this is a test'
    Traceback (most recent call last):
    File "Builder/Scripts/AudioTemplates/text_to_speech.py", line 10, in <module>
        import soundfile as sf
    ModuleNotFoundError: No module named 'soundfile'
  ``` [Claude]
- Command for CLI AI has to be customizable with the def. val. and to run in headless mode
- Fixers: Add support for multiple `Fixers` - Besides `Claude` add `Qwen` as option/default one [Claude]
- Add all Upstreams supported: GitLab, GitFlic, Gitee, GitVerse
- TASK: [004 Cover all models by all supported Builder categories](../AITasks/Tasks/004%20Cover%20all%20models%20by%20all%20supported%20Builder%20categories/TASK.md) [Claude]
- Write log files during the testing [Claude]
- TASK: [FIXME: 005 Make sure that tests are running with no errors or warnings](../AITasks/Tasks/005%20Fix%20errors%20produced%20during%20the%20tests%20execution/TASK.md) [Qwen]
- TASK: [006 Hello Qwen](../AITasks/Tasks/006%20Hello%20Qwen/TASK.md) [Qwen]
- Using local project-level Gemini fork with Ollama
