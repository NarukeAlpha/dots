# Mutable Harness and Platform Adapter Architecture

## Problem

You are building an app that must work across multiple external platforms,
harnesses, accounts, runtimes, repositories, or execution environments.

Examples:

- GitHub
- Azure DevOps
- GitLab
- AWS CodeCommit
- Local Git repositories
- Remote development servers
- Cloud workspaces
- CI/CD systems
- Enterprise self-hosted variants

The app should not need a broad rewrite every time a new platform is added. It
should remain stable while integrations are added, removed, reconfigured,
upgraded, downgraded, or temporarily unavailable.

## Core Idea

Treat each external system as a runtime instance behind a stable contract.

Do not build the app around hard-coded platform branches like this:

```ts
if (provider === "github") {
  // GitHub behavior
}

if (provider === "azure-devops") {
  // Azure DevOps behavior
}

if (provider === "aws") {
  // AWS behavior
}
```

Instead, build around these concepts:

```ts
driverKind;   // which implementation handles this instance
instanceId;   // which configured runtime/account/environment to route to
capabilities; // what this instance can currently do
adapter;      // normalized operations exposed to the app
events;       // canonical domain events
snapshot;     // current health, auth, config, and feature state
```

The platform becomes data that selects an adapter. It should not become a mode
that rewires the whole application.

## Separate Driver Type From Instance Identity

A driver kind identifies an implementation:

```ts
type DriverKind =
  | "github"
  | "azure-devops"
  | "gitlab"
  | "aws-codecommit"
  | "local-git";
```

An instance id identifies one configured runtime:

```ts
type InstanceId =
  | "github_work"
  | "github_personal"
  | "ado_client_a"
  | "aws_prod_us_east"
  | "gitlab_enterprise";
```

Route by `instanceId`, not by `driverKind`.

This allows multiple accounts, organizations, regions, tenants, or enterprise
hosts to use the same underlying driver without sharing mutable state.

## Driver Contract

Each driver should be a plain factory that creates one isolated runtime
instance.

```ts
interface PlatformDriver<Config> {
  readonly kind: DriverKind;
  readonly configSchema: Schema<Config>;
  readonly defaultConfig: () => Config;

  readonly create: (input: {
    readonly instanceId: InstanceId;
    readonly displayName?: string;
    readonly config: Config;
    readonly environment?: Record<string, string>;
    readonly enabled: boolean;
  }) => Promise<PlatformInstance>;
}
```

The driver owns platform-specific details. The rest of the app should not know
how GitHub, Azure DevOps, GitLab, or AWS APIs differ.

## Instance Contract

Each created instance should bundle the same normalized capabilities:

```ts
interface PlatformInstance {
  readonly instanceId: InstanceId;
  readonly driverKind: DriverKind;
  readonly enabled: boolean;

  readonly snapshot: PlatformSnapshotService;
  readonly adapter: PlatformAdapter;
  readonly events: EventStream<CanonicalPlatformEvent>;

  readonly dispose: () => Promise<void>;
}
```

Each instance owns its own clients, auth state, caches, subprocesses, webhooks,
polling loops, and cleanup lifecycle.

Two instances of the same driver must not share mutable state unless that state
is intentionally external and explicitly keyed.

## Adapter Contract

Expose platform operations through normalized capability groups.

```ts
interface PlatformAdapter {
  readonly repositories?: {
    readonly list: (input: ListRepositoriesInput) => Promise<Repository[]>;
    readonly read: (input: ReadRepositoryInput) => Promise<Repository>;
  };

  readonly changeRequests?: {
    readonly list: (input: ListChangeRequestsInput) => Promise<ChangeRequest[]>;
    readonly get: (input: GetChangeRequestInput) => Promise<ChangeRequest>;
    readonly create: (input: CreateChangeRequestInput) => Promise<ChangeRequest>;
  };

  readonly branches?: {
    readonly list: (input: ListBranchesInput) => Promise<Branch[]>;
  };

  readonly checks?: {
    readonly get: (input: GetChecksInput) => Promise<CheckRun[]>;
  };

  readonly workflows?: {
    readonly trigger: (input: TriggerWorkflowInput) => Promise<WorkflowRun>;
  };
}
```

Platform-specific differences belong inside the adapter, not in UI or
orchestration code.

The adapter surface should line up with capability discovery. If
`capabilities.workflows` is false, `adapter.workflows` should be absent rather
than present and failing at runtime.

## Capability Snapshots

Every instance should publish a snapshot describing its current state.

```ts
interface PlatformSnapshot {
  readonly instanceId: InstanceId;
  readonly driverKind: DriverKind;
  readonly displayName: string;

  readonly availability: "available" | "unavailable";
  readonly enabled: boolean;
  readonly authStatus: "authenticated" | "unauthenticated" | "unknown";

  readonly capabilities: {
    readonly repositories: boolean;
    readonly localWorkingTree: boolean;
    readonly changeRequests: boolean;
    readonly reviewComments: boolean;
    readonly checks: boolean;
    readonly workflows: boolean;
    readonly deployments: boolean;
    readonly branchProtection: boolean;
    readonly webhooks: boolean;
  };

  readonly message?: string;
  readonly checkedAt: string;
}
```

The UI should render from this snapshot rather than assuming features by
platform name.

Examples:

- Show "Create PR" only when `capabilities.changeRequests` is true.
- Show "Run workflow" only when `capabilities.workflows` is true.
- Show "Open local diff" only when `capabilities.localWorkingTree` is true.
- Show auth warnings from `authStatus` and `message`.

## Registry Pattern

Use a registry to reconcile desired configuration into live runtime instances.

```ts
class PlatformInstanceRegistry {
  reconcile(configMap: Record<InstanceId, InstanceConfig>): Promise<void>;
  get(instanceId: InstanceId): PlatformInstance | undefined;
  list(): PlatformInstance[];
  listUnavailable(): PlatformSnapshot[];
  onChange(callback: () => void): Unsubscribe;
}
```

`reconcile()` should:

- create new instances
- keep unchanged instances alive
- rebuild changed instances
- dispose removed instances
- emit unavailable snapshots for invalid or unsupported configs

This registry is the heart of runtime mutability.

Do not mutate provider clients in place. Reconcile desired config to live
handles.

## Opaque Config Envelopes

Store driver config in a generic envelope.

```ts
interface InstanceConfig {
  readonly driverKind: DriverKind;
  readonly schemaVersion: number;
  readonly displayName?: string;
  readonly enabled?: boolean;
  readonly config?: unknown;
}
```

Only the driver decodes `config`.

This lets newer configs, plugin-only drivers, fork-only drivers, or temporarily
unsupported integrations survive round trips without data loss.

## Unavailable Shadow Instances

Unknown or broken drivers should not crash the app.

Instead, preserve their config and expose a synthetic snapshot:

```ts
const snapshot = {
  instanceId: "aws_enterprise",
  driverKind: "aws-codecommit",
  availability: "unavailable",
  enabled: false,
  authStatus: "unknown",
  capabilities: {
    repositories: false,
    localWorkingTree: false,
    changeRequests: false,
    reviewComments: false,
    checks: false,
    workflows: false,
    deployments: false,
    branchProtection: false,
    webhooks: false,
  },
  message: "Driver is not installed in this build.",
  checkedAt: new Date().toISOString(),
};
```

This makes downgrades, feature flags, plugin systems, and enterprise deployments
safer.

## Canonical Events

Normalize platform-specific events into app-level events.

```ts
type CanonicalPlatformEvent =
  | { type: "repository.detected"; payload: Repository }
  | { type: "repository.changed"; payload: Repository }
  | { type: "change_request.opened"; payload: ChangeRequest }
  | { type: "change_request.updated"; payload: ChangeRequest }
  | { type: "check.completed"; payload: CheckRun }
  | { type: "deployment.failed"; payload: Deployment }
  | { type: "auth.changed"; payload: AuthState }
  | { type: "runtime.error"; payload: RuntimeError };
```

Keep raw native payloads only for diagnostics.

The app should consume the canonical event stream, not native GitHub webhook
payloads, Azure DevOps service hook payloads, GitLab webhook payloads, or AWS
event shapes directly.

## Environment Scoping

Never use globally ambiguous ids like `repo`, `project`, `pullRequestNumber`, or
`branch` alone.

Prefer scoped identities:

```ts
interface ScopedRepositoryRef {
  readonly environmentId: string;
  readonly platformInstanceId: InstanceId;
  readonly repositoryId: string;
}

interface ScopedChangeRequestRef {
  readonly environmentId: string;
  readonly platformInstanceId: InstanceId;
  readonly repositoryId: string;
  readonly changeRequestId: string;
}
```

This avoids collisions across accounts, organizations, enterprise hosts,
regions, and remote workspaces.

Use `environmentId` only when the same platform instance can be mounted into
multiple runtime contexts. If not, omit it and let `platformInstanceId` be the
top-level scope.

## UI Pattern

The UI should consume instance entries, not platform branches.

```ts
interface PlatformInstanceEntry {
  readonly instanceId: InstanceId;
  readonly driverKind: DriverKind;
  readonly displayName: string;
  readonly status: "ready" | "warning" | "error" | "disabled";
  readonly capabilities: PlatformSnapshot["capabilities"];
}
```

Render generic surfaces from instance entries:

- instance picker
- repository picker
- branch picker
- change request list
- auth status
- connection health
- available actions

Provider-specific UI should be isolated to small presentation adapters, such as
icons, terminology, and field labels.

## Discovery Pattern

Add a discovery layer that probes what exists.

```ts
interface DiscoveryResult {
  readonly drivers: DriverDiscoveryItem[];
  readonly instances: InstanceDiscoveryItem[];
  readonly auth: AuthDiscoveryItem[];
}
```

Probe:

- CLI installed
- API reachable
- auth valid
- token scopes sufficient
- enterprise host reachable
- repo remote provider detected
- local VCS state detected
- permissions available

Prefer capability discovery over hard-coded assumptions.

## Split Local VCS From Hosted Source Control

Local repository mechanics and hosted provider operations are separate layers.

Local VCS operations:

- detect repository root
- read status
- list branches
- read remotes
- compute diffs
- stage/unstage files
- commit
- create/switch worktrees

Hosted source-control operations:

- list pull requests or merge requests
- create change requests
- review/comment
- read checks
- read deployments
- manage branches and protections through provider APIs

GitHub is not "Git". Azure DevOps is not "Git". GitLab is not "Git".

Use a `VcsDriver` for local repo behavior and a `PlatformDriver` or
`SourceControlDriver` for hosted provider behavior.

## Migration Rule

Compatibility should live at schema boundaries.

Old shapes should decode into new canonical shapes early:

```ts
// Legacy
{ provider: "github", repo: "owner/name" }

// Canonical
{ instanceId: "github_personal", repositoryId: "owner/name" }
```

After decoding, runtime code should only use the new canonical shape.

## Anti-Patterns

Avoid:

- routing by provider name instead of instance id
- singleton clients for providers that can have multiple accounts
- UI code full of provider-specific conditionals
- partial config patching that can leave invalid mixed state
- deleting unknown config because the current build cannot understand it
- assuming GitHub, Azure DevOps, GitLab, and AWS share terminology
- treating local VCS and hosted source control as the same layer
- storing unscoped ids that collide across environments
- making auth global when it is actually per instance

## Recommended Shape

```txt
Settings
  -> instance config envelopes
  -> registry reconcile
  -> scoped runtime instances
  -> normalized adapters
  -> capability snapshots
  -> canonical events
  -> generic UI and orchestration
```

## Takeaway

The durable pattern is stable envelopes plus dynamic registries plus capability
snapshots.

That gives you an app that can mutate by harness, platform, account, tenant,
region, server, or local runtime without turning the rest of the system into a
large set of provider-specific branches.
