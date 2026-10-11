// Minimal Luau runner for tests outside Roblox.
//   luaurun <script.luau> [args...]
// Globals: loadModule(path) -> value, readFile(path) -> string, listDir(path) -> {names}, isDir(path) -> bool,
//          loadChunk(code, chunkName, envTable) -> function, ARGS = {args...}
use mlua::{Function, Lua, Result, Table, Value};
fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let path = args.get(1).expect("usage: luaurun <file>").clone();
    let lua = Lua::new();
    let g = lua.globals();
    g.set("loadModule", lua.create_function(|lua, p: String| {
        let code = std::fs::read_to_string(&p).map_err(|e| mlua::Error::external(format!("{p}: {e}")))?;
        lua.load(&code).set_name(p).eval::<Value>()
    })?)?;
    g.set("readFile", lua.create_function(|_, p: String| {
        std::fs::read_to_string(&p).map_err(|e| mlua::Error::external(format!("{p}: {e}")))
    })?)?;
    g.set("isDir", lua.create_function(|_, p: String| Ok(std::path::Path::new(&p).is_dir()))?)?;
    g.set("listDir", lua.create_function(|lua, p: String| {
        let t = lua.create_table()?;
        let mut names: Vec<String> = std::fs::read_dir(&p).map_err(mlua::Error::external)?
            .filter_map(|e| e.ok()).map(|e| e.file_name().to_string_lossy().to_string()).collect();
        names.sort();
        for (i, n) in names.into_iter().enumerate() { t.set(i + 1, n)?; }
        Ok(t)
    })?)?;
    g.set("loadChunk", lua.create_function(|lua, (code, name, env): (String, String, Table)| {
        let f: Function = lua.load(&code).set_name(name).set_environment(env).into_function()?;
        Ok(f)
    })?)?;
    let t = lua.create_table()?;
    for (i, a) in args.iter().skip(2).enumerate() { t.set(i + 1, a.clone())?; }
    g.set("ARGS", t)?;
    let src = std::fs::read_to_string(&path).expect("read");
    lua.load(&src).set_name(path).exec()
}
