"""Package the built WebUI and module scripts, retaining existing outputs."""
from pathlib import Path
import argparse
import zipfile

root=Path(__file__).resolve().parent.parent
p=argparse.ArgumentParser();p.add_argument('--output',required=True,type=Path);a=p.parse_args()
module=root/'module'
for name in ('module.prop','webui/index.html','target-automation.sh','target-merge.awk'):
    if not (module/name).is_file():raise SystemExit('Build input missing: '+name)
a.output.parent.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(a.output,'x',zipfile.ZIP_DEFLATED) as z:
    for f in sorted(module.rglob('*')):
        if not f.is_file():continue
        name=f.relative_to(module).as_posix()
        i=zipfile.ZipInfo(name);i.create_system=3
        i.external_attr=(0o100755 if f.suffix=='.sh' or f.name=='update-binary' else 0o100644)<<16
        i.compress_type=zipfile.ZIP_DEFLATED;z.writestr(i,f.read_bytes())
    z.writestr('LICENSE',(root/'LICENSE').read_bytes())
    z.writestr('LOCAL_BUILD.md',(root/'CHANGELOG_LOCAL.md').read_bytes())
print(a.output)
