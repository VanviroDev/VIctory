//! `victory`: the command-line front end.
//!
//! Every command reads the user's own files and writes only to stdout or to
//! the user's cache directory (outside the repository).

mod census;
mod inspect;
mod run;
mod shader;
mod translate;

use std::path::PathBuf;

use anyhow::Result;
use clap::{Parser, Subcommand, ValueEnum};

/// Which D3D12 Agility SDK this executable asks the system `d3d12.dll`
/// for. The translated shaders are shader model 6.6 and index the view and
/// sampler heaps directly, and neither exists in the D3D12 that ships with
/// Windows 10 (10.0.19041 tops out at 6.5 and refuses the
/// `*_HEAP_DIRECTLY_INDEXED` root signature flags outright). With these
/// two exports present, `d3d12.dll` loads `D3D12Core.dll` from
/// `D3D12SDKPath` beside the executable instead, and the whole feature set
/// is there on Windows 10 as well as 11.
///
/// The version must match the shipped core exactly: 620 for 1.620.x.
#[unsafe(no_mangle)]
pub static D3D12SDKVersion: u32 = 620;

/// Relative to the executable, and it must end with a separator. A pointer
/// (not an array): `d3d12.dll` reads the value at this symbol.
#[unsafe(no_mangle)]
pub static D3D12SDKPath: &[u8; 9] = b".\\D3D12\\\0";

#[derive(Parser)]
#[command(
    name = "victory",
    version,
    about = "Run an Xbox Series title natively on Windows"
)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Summarise one PE image: headers, sections, imports, TLS, build id.
    Inspect {
        file: PathBuf,
        /// List every imported function.
        #[arg(long)]
        imports: bool,
        /// List every exported function.
        #[arg(long)]
        exports: bool,
    },
    /// Aggregate the imports of every PE image under the given paths and
    /// show which ones our runtime covers. Defaults to the configured
    /// game and test-title directories.
    Census {
        paths: Vec<PathBuf>,
        /// Do not count host pass-through as covered.
        #[arg(long)]
        strict: bool,
        /// List every missing `dll!function`, most used first.
        #[arg(long)]
        missing: bool,
    },
    /// List the `dll!export` pairs an import library describes.
    LibExports {
        lib: PathBuf,
        /// List every export, not just per-DLL counts.
        #[arg(long)]
        list: bool,
    },
    /// Find shader containers in files or directories (also inside engine
    /// archives, if uncompressed) and report their layout.
    ShaderInfo {
        paths: Vec<PathBuf>,
        /// Print one line per container found.
        #[arg(long)]
        verbose: bool,
        /// Also list the decoded native instructions (implies --verbose).
        #[arg(long)]
        disasm: bool,
    },
    /// Run every shader found (containers, SGD5 files) through the
    /// translator and report what it cannot handle yet.
    Translate {
        paths: Vec<PathBuf>,
        /// Check emitted DXIL with dxil.dll's validator (`VICTORY_DXIL`,
        /// else the newest Windows SDK's).
        #[arg(long)]
        validate: bool,
        /// Also create a host D3D12 pipeline for each emitted shader.
        #[arg(long)]
        pipelines: bool,
        /// Print one line per program and outcome.
        #[arg(long)]
        list: bool,
        /// Worker threads (default: every logical core).
        #[arg(long)]
        jobs: Option<usize>,
    },
    /// Translate the shaders of a title's archives into the cache and make
    /// their compute pipelines, so that a run finds them there.
    Warm {
        #[command(flatten)]
        rays: RayOptions,
        paths: Vec<PathBuf>,
        /// Worker threads (default: every logical core).
        #[arg(long)]
        jobs: Option<usize>,
        /// Only translate: no host pipelines.
        #[arg(long)]
        no_pipelines: bool,
    },
    /// Prepare, map and bind a title executable; with --execute, run it.
    Run {
        #[command(flatten)]
        rays: RayOptions,
        exe: PathBuf,
        /// What unimplemented imports do when called.
        #[arg(long, value_enum, default_value_t = Unimplemented::Trap)]
        unimplemented: Unimplemented,
        /// Disable host pass-through (everything must be implemented by us).
        #[arg(long)]
        strict: bool,
        /// Actually start the title. Without it, stop after binding.
        #[arg(long)]
        execute: bool,
        /// The console model the title sees (device type, memory).
        #[arg(long, value_enum, default_value_t = Console::SeriesX)]
        console: Console,
        /// Arguments for the title, after `--` (it reads the whole command
        /// line; a title that relaunches itself passes some).
        #[arg(last = true)]
        title_args: Vec<String>,
    },
    /// Show the resolved configuration and check it.
    Config,
}

#[derive(clap::Args)]
struct RayOptions {
    /// Enable experimental ray tracing.
    #[arg(long)]
    rt: bool,
    /// Disable the ray structure builder, traversal, activation and hit resolve.
    #[arg(long)]
    no_rt: bool,
    /// Trace against the prebuilt world BVH without rebuilding dynamic geometry.
    #[arg(long, conflicts_with_all = ["rt", "no_rt"])]
    rt_static_bvh: bool,
}

impl RayOptions {
    fn selected(&self, preference: Option<bool>) -> Option<bool> {
        if self.no_rt { Some(false) } else if self.rt { Some(true) } else { preference }
    }

    #[cfg(windows)]
    fn apply(&self, cfg: &victory_core::Config) {
        if self.rt_static_bvh {
            // SAFETY: Windows supports setting the process environment across threads.
            unsafe { std::env::set_var("VICTORY_RAY_TRACING", "static-bvh") };
            return;
        }
        if !self.rt && !self.no_rt && std::env::var("VICTORY_RAY_TRACING").as_deref() == Ok("static-bvh") {
            return;
        }
        if let Some(on) = self.selected(cfg.ray_tracing) {
            // SAFETY: Windows supports updating the process environment even
            // when logging threads exist. Title-requested relaunches inherit it.
            unsafe { std::env::set_var("VICTORY_RAY_TRACING", if on { "1" } else { "0" }) };
        }
    }
}

#[cfg(test)]
mod ray_cli_tests {
    use super::*;

    #[test]
    fn normal_run_and_warm_keep_cli_precedence() {
        for (mode, expected) in [
            (vec![], Some(true)), (vec!["--rt"], Some(true)), (vec!["--no-rt"], Some(false)),
            (vec!["--rt", "--no-rt"], Some(false)), (vec!["--no-rt", "--rt"], Some(false)),
        ] {
            for verb in ["run", "warm"] {
                let args = ["victory", verb, "file"].into_iter().chain(mode.iter().copied());
                let cli = Cli::try_parse_from(args).unwrap();
                let rays = match cli.command { Command::Run { rays, .. } | Command::Warm { rays, .. } => rays, _ => unreachable!() };
                assert_eq!(rays.selected(Some(true)), expected);
            }
        }
        assert_eq!(RayOptions { rt: false, no_rt: false, rt_static_bvh: false }.selected(None), None);
    }
}

#[derive(Clone, Copy, ValueEnum)]
enum Unimplemented {
    Trap,
    Zero,
}

#[derive(Clone, Copy, ValueEnum)]
enum Console {
    SeriesX,
    SeriesS,
}

fn main() -> Result<()> {
    victory_core::logging::init("info");
    // The audio recorder `run` starts for `VICTORY_AUDIO_CAPTURE`.
    #[cfg(all(windows, feature = "diagnostics"))]
    if victory_hle::modules::audio::capture::child() {
        return Ok(());
    }
    let cli = Cli::parse();
    match cli.command {
        Command::Inspect {
            file,
            imports,
            exports,
        } => inspect::run(&file, imports, exports),
        Command::Census {
            paths,
            strict,
            missing,
        } => census::run(paths, strict, missing),
        Command::LibExports { lib, list } => inspect::lib_exports(&lib, list),
        Command::ShaderInfo {
            paths,
            verbose,
            disasm,
        } => shader::run(paths, verbose || disasm, disasm),
        Command::Translate {
            paths,
            validate,
            pipelines,
            list,
            jobs,
        } => {
            // `VICTORY_VIEW_LIMIT=<null slot>`: translate as on a host whose view heap is capped
            if let Some(n) = std::env::var("VICTORY_VIEW_LIMIT").ok().and_then(|v| v.parse().ok()) {
                victory_shader::emit::set_view_heap_limit(n);
            }
            // `VICTORY_HOST_WAVE=32`: translate as for a GPU whose waves are at most 32 lanes
            if let Some(n) = std::env::var("VICTORY_HOST_WAVE").ok().and_then(|v| v.parse().ok()) {
                victory_shader::emit::set_host_max_wave(n);
            }
            translate::run(paths, validate, pipelines, list, jobs)
        }
        Command::Warm { rays, paths, jobs, no_pipelines } => {
            translate::warm(paths, jobs, !no_pipelines, rays)
        }
        Command::Run {
            rays,
            exe,
            unimplemented,
            strict,
            execute,
            console,
            title_args: _,
        } => {
            let result = run::run(&exe, unimplemented, strict, execute, console, rays);
            // The process's own end, as `main`'s Result maps it: Ok is 0,
            // Err is 1. A title that ends the process itself logs its own
            // line and never returns here.
            let code = if result.is_ok() { 0 } else { 1 };
            tracing::info!("runtime exit: code {code}");
            result
        }
        Command::Config => show_config(),
    }
}

fn show_config() -> Result<()> {
    let cfg = victory_core::Config::load()?;
    let status = |p: &Option<PathBuf>| match p {
        Some(p) if p.exists() => format!("{}", p.display()),
        Some(p) => format!("{}  (does not exist)", p.display()),
        None => "(not set)".to_owned(),
    };
    println!(
        "config file : {}",
        cfg.source
            .as_ref()
            .map_or("(none)".into(), |p| p.display().to_string())
    );
    println!("game_dir    : {}", status(&cfg.game_dir));
    println!("ray_tracing : {}", match cfg.ray_tracing { Some(true) => "on", Some(false) => "off", None => "individual stage settings" });
    println!("cache_dir   : {}", cfg.cache_dir.display());
    println!("data_dir    : {}", cfg.data_dir.display());
    for t in &cfg.test_titles {
        println!("test_title  : {}", status(&Some(t.clone())));
    }
    for p in cfg
        .game_dir
        .iter()
        .chain(&cfg.test_titles)
        .chain([&cfg.cache_dir, &cfg.data_dir])
    {
        if let Err(e) = victory_core::ensure_outside_repo(p) {
            println!("POLICY VIOLATION: {e}");
        }
    }
    Ok(())
}

/// Paths given on the command line, or the configured game + test titles.
pub(crate) fn default_paths(paths: Vec<PathBuf>) -> Result<Vec<PathBuf>> {
    if !paths.is_empty() {
        return Ok(paths);
    }
    let cfg = victory_core::Config::load()?;
    let all: Vec<PathBuf> = cfg.game_dir.into_iter().chain(cfg.test_titles).collect();
    anyhow::ensure!(
        !all.is_empty(),
        "no paths given and none configured (see victory.example.toml)"
    );
    Ok(all)
}
