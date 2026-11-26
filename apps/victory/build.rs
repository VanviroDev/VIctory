// The two Agility SDK exports are read out of the executable's export
// table by the system `d3d12.dll`, and a static alone does not put a name
// there: the linker needs to be told. Only the `victory` binary makes the
// device; `victory-play` and `victory-warm` are launchers that spawn it.
fn main() {
    println!("cargo:rustc-link-arg-bin=victory=/EXPORT:D3D12SDKVersion");
    println!("cargo:rustc-link-arg-bin=victory=/EXPORT:D3D12SDKPath");
}
