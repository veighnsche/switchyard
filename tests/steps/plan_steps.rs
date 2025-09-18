use cucumber::{given, when};

use crate::bdd_support::env::EnvGuard;
use crate::bdd_world::World;
use switchyard::api::{Overrides, Switchyard};
use switchyard::policy::types::SmokePolicy;

#[given(regex = r"^(/.+) is a symlink to (.+)$")]
pub async fn given_symlink(world: &mut World, link: String, dest: String) {
    world.mk_symlink(&link, &dest);
}

#[given(regex = r"^a plan with at least one action$")]
pub async fn given_plan_min(world: &mut World) {
    let link = world
        .last_link
        .clone()
        .unwrap_or_else(|| format!("/{}/bin/{}", "usr", "ls"));
    let src = world
        .last_src
        .clone()
        .unwrap_or_else(|| "providerB/ls".to_string());
    world.build_single_swap(&link, &src);
}

#[given(regex = r"^the target and staging directories reside on different filesystems$")]
pub async fn given_exdev_env(world: &mut World) {
    // Use per-instance override to simulate EXDEV deterministically, avoiding process-global env.
    let mut builder = Switchyard::builder(
        world.facts.clone(),
        world.audit.clone(),
        world.policy.clone(),
    );
    // Preserve a LockManager if configured by the scenario
    if let Some(lock_path) = &world.lock_path {
        builder = builder.with_lock_manager(Box::new(switchyard::adapters::FileLockManager::new(
            lock_path.clone(),
        )));
    }
    // Preserve an explicitly configured smoke runner
    if let Some(kind) = world.smoke_runner {
        match kind {
            crate::bdd_world::SmokeRunnerKind::Default => {
                builder =
                    builder.with_smoke_runner(Box::new(switchyard::adapters::DefaultSmokeRunner));
            }
            crate::bdd_world::SmokeRunnerKind::Failing => {
                #[derive(Debug, Default)]
                struct Failing;
                impl switchyard::adapters::SmokeTestRunner for Failing {
                    fn run(
                        &self,
                        _plan: &switchyard::types::plan::Plan,
                    ) -> Result<(), switchyard::adapters::smoke::SmokeFailure> {
                        Err(switchyard::adapters::smoke::SmokeFailure)
                    }
                }
                builder = builder.with_smoke_runner(Box::new(Failing));
            }
        }
    }
    let api = builder.build().with_overrides(Overrides::exdev(true));
    world.api = Some(api);
}

#[given(regex = r"^the minimal post-apply smoke suite is configured$")]
pub async fn given_smoke(world: &mut World) {
    world.policy.governance.smoke = SmokePolicy::Require {
        auto_rollback: true,
    };
    let api = switchyard::api::Switchyard::builder(
        world.facts.clone(),
        world.audit.clone(),
        world.policy.clone(),
    )
    .with_smoke_runner(Box::new(switchyard::adapters::DefaultSmokeRunner))
    .build();
    world.api = Some(api);
    world.smoke_runner = Some(crate::bdd_world::SmokeRunnerKind::Default);
}

#[when(regex = r"^I plan a swap to (\S+)$")]
pub async fn when_plan_swap(world: &mut World, provider: String) {
    let link = world
        .last_link
        .clone()
        .unwrap_or_else(|| format!("/{}/bin/{}", "usr", "ls"));
    let src = format!("{}/ls", provider);
    world.build_single_swap(&link, &src);
}

#[given(regex = r"^a plan that mutates a file$")]
pub async fn given_plan_mutates(world: &mut World) {
    // Ensure a regular file exists at target so swap creates backup and after_kind changes
    let root = world.ensure_root().to_path_buf();
    let link = &format!("/{}/bin/{}", "usr", "cp");
    let target = crate::bdd_support::util::under_root(&root, link);
    if let Some(p) = target.parent() {
        let _ = std::fs::create_dir_all(p);
    }
    let _ = std::fs::write(&target, b"old");
    world.mk_symlink(link, "providerA/cp");
    world.build_single_swap(link, "providerB/cp");
}

#[given(regex = r"^a plan with environment-derived values that may be sensitive$")]
pub async fn given_plan_env_sensitive(world: &mut World) {
    world
        .env_guards
        .push(EnvGuard::new("SWITCHYARD_HELPER", "paru"));
    given_plan_min(world).await;
}

#[given(regex = r"^a plan that uses an external helper$")]
pub async fn given_plan_external_helper(world: &mut World) {
    given_plan_env_sensitive(world).await
}
