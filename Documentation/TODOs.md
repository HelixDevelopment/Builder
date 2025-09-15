# TODOs

- For each category create debate AI group
  - Expose the debate group via Ollama for API access

## In progress

- FIXME:

  ```bash
   ✘ python3 Scripts/AudioTemplates/text_to_speech.py 'Hello, this is a test'
    Traceback (most recent call last):
    File "Builder/Scripts/AudioTemplates/text_to_speech.py", line 10, in <module>
        import soundfile as sf
    ModuleNotFoundError: No module named 'soundfile'
  ```

## Completed

- FIXME: Audio model for 7B does not exist on Ollama
- Make sure that every model before it is installed is checked if exists in Ollama, as fallback pull it and apply from Hugging Face
- TASK: [003 Testing Scripts](../Claude/Tasks/003%20Testing%20Scripts/TASK.md)
