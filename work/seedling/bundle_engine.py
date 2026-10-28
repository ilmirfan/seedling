import pathlib,subprocess,shutil
root=pathlib.Path(__file__).resolve().parent
app=root/'build/Seedling.app/Contents'
binary=next((root/'engine/transmission-cli').rglob('bin/transmission-daemon'))
target=app/'MacOS/transmission-daemon';shutil.copy2(binary,target)
frameworks=app/'Frameworks';frameworks.mkdir(parents=True,exist_ok=True)
licenses=app/'Resources/Licenses';licenses.mkdir(parents=True,exist_ok=True)
for component in ['transmission-cli','miniupnpc','libpsl']:
 for p in (root/'engine'/component).rglob('*'):
  if p.name in ['LICENSE','COPYING','AUTHORS','COPYRIGHT'] and p.is_file():shutil.copy2(p,licenses/(component+'-'+p.name))
visited=set()
def vendor(path):
 if path in visited:return
 visited.add(path)
 subprocess.run(['chmod','u+w',str(path)],check=True)
 deps=subprocess.check_output(['otool','-L',str(path)],text=True).splitlines()[1:]
 for line in deps:
  old=line.strip().split(' (')[0]
  if not (old.startswith('/opt/homebrew/') or old.startswith('@@HOMEBREW_PREFIX@@/')):continue
  basename=pathlib.Path(old.replace('@@HOMEBREW_PREFIX@@','/opt/homebrew')).name
  new=frameworks/basename
  if path==new:continue
  if not new.exists():
   candidates=[p for p in (root/'engine').rglob(basename) if p.is_file()]
   source=candidates[0] if candidates else pathlib.Path(old.replace('@@HOMEBREW_PREFIX@@','/opt/homebrew'))
   if not source.exists():raise RuntimeError('Missing dependency '+old)
   shutil.copy2(source,new);vendor(new)
   if '/Cellar/' in str(source.resolve()):
    package=source.resolve().parent.parent
    for notice in ['LICENSE','COPYING','COPYRIGHT']:
     if (package/notice).is_file():shutil.copy2(package/notice,licenses/(package.parent.name+'-'+notice))
   subprocess.run(['install_name_tool','-id','@rpath/'+basename,str(new)],check=True)
  replacement=('@executable_path/../Frameworks/' if path==target else '@loader_path/')+basename
  subprocess.run(['install_name_tool','-change',old,replacement,str(path)],check=True)
vendor(target)
for lib in frameworks.iterdir():subprocess.run(['codesign','--force','--sign','-',str(lib)],check=True,stdout=subprocess.DEVNULL)
subprocess.run(['codesign','--force','--sign','-',str(target)],check=True,stdout=subprocess.DEVNULL)
print('Bundled standalone engine and',len(list(frameworks.iterdir())),'libraries')
