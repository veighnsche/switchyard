pub mod api_safety;
pub mod atomicity;
pub mod conservatism_ci;
pub mod degraded_fs;
pub mod determinism;
pub mod error_taxonomy;
pub mod locking_aliases;
pub mod rescue_aliases;
pub mod smoke;

// Re-exports for cross-module convenience
pub use conservatism_ci::then_side_effects_not_performed;
