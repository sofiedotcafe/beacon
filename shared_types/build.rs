use crux_core::typegen::TypeGen;
use shared::Beacon;
use std::path::PathBuf;

fn main() -> anyhow::Result<()> {
    println!("cargo:rerun-if-changed=../shared");

    let mut gen = TypeGen::new();
    gen.register_app::<Beacon>()?;

    let output_root = PathBuf::from("./generated");

    gen.java("cafe.sofie.beacon.crux", output_root.join("java"))?;

    Ok(())
}
