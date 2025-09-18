# TODOs

- For each category create debate AI group
  - Expose the debate group via Ollama for API access

## In progress

- Cover all models by all supported Builder categories
- Integrate RAG with Fixers to pickup from out memory database
- Fixers: Support for Goose
- Fixers: Auto detection between AI CLIs sorted by priority - claude, goose, qwen, etc
- Web UI for tasks with APIs (instead of manual editing). After we create or edit task submit with confirmation sends it to execution to the AI
- Recipes for adding more tests (each test scenario is defined by the recipe)

## Completed

- FIXME: Audio model for 7B does not exist on Ollama
- Make sure that every model before it is installed is checked if exists in Ollama, as fallback pull it and apply from Hugging Face
- TASK: [003 Testing Scripts](../Claude/Tasks/003%20Testing%20Scripts/TASK.md)
- FIXME:

  ```bash
   ✘ python3 Scripts/AudioTemplates/text_to_speech.py 'Hello, this is a test'
    Traceback (most recent call last):
    File "Builder/Scripts/AudioTemplates/text_to_speech.py", line 10, in <module>
        import soundfile as sf
    ModuleNotFoundError: No module named 'soundfile'
  ```
- Command for CLI AI has to be customizable with the def. val. and to run in headless mode
- Fixers: Add support for multiple `Fixers` - Besides `Claude` add `Qwen` as option/default one
- Add all Upstreams supported: GitLab, GitFlic, Gitee, GitVerse

