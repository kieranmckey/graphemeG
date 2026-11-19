# Web playtesting

The Web export is deployed to GitHub Pages when a commit is pushed to `main`
or `master`. It can also be started manually from the Actions tab with
**Deploy web playtest**.

For the first deployment, set the repository's Pages source to **GitHub Actions**
in **Settings > Pages**. The workflow exports with Godot 4.7.1 and deploys
`build/web`; its URL is shown in the deployment job.

To export locally, install the Godot 4.7.1 export templates and run:

```powershell
godot --headless --editor --path . --import
New-Item -ItemType Directory -Force build\web | Out-Null
godot --headless --path . --export-release "Web" build\web\index.html
```
