# Testing Scripts

Before you start check all directories under `AITAsks/Tasks`. Each directory is one task done by you.
Completed tasks have report markdown file: `TASK_REPORT.md`. Go through each report to learn what you have done so far with the project.

After you are done with this, please extend the testing script(s) to support all of our models:

- `General`
- `Coder`
- `Tester`
- `Translation`
- `Generative/Animation`
- `Generative/Audio`
- `Generative/JPEG`
- `Generative/PNG`
- `Generative/SVG`

Currently, only the `General` category is supported. Check this out in `Scripts/test.sh` script. Line as reference:

`local models_file="$HERE/Recipes/Models/General/$model_size"`

As tou can see the script targets only the `General` models recipes. We want to extend the testing to all supported categories and models.

Once you have extended the project verify that no bugs in the scripts are intorduced and that everything works as expected.
For this task write its `TASK_REPORT.md` so you can continue next time with next / upcoming task. `TASK_REPORT.md` file should go into the directory of this task: `AITasks/004 Cover all models by all supported Builder categories/TASK_REPORT.md`.
