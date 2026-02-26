# mas-opa-policies

This repo defines **request-level policy rules** across the MAS platform.

## Why this repo exists

The platform already has authentication (Keycloak) and relationship-based authorization (OpenFGA — "is user X allowed to access resource Y?"). What was missing is **policy-based authorization** — the ability to enforce rules like "request payloads must not exceed 100KB", "restricted tools require admin team membership", "only authenticated users can invoke MCP tools".

OPA (Open Policy Agent) fills this gap. It evaluates structured requests against Rego policies and returns allow/deny decisions. Where OpenFGA answers "who can access what", OPA answers "is this specific request allowed given its content, context, and rules".

This repo makes policy management **self-service for app teams**:

- **Each team owns their policies.** The MCP team defines tool invocation rules in `policies/mcp/`, the demo team defines request validation in `policies/demo/`, etc.
- **Changes deploy automatically.** Push to `main` and CI tests your policies, then deploys them to OPA. No manual API calls.
- **Everything is auditable.** Every policy change is a Git commit with a diff, an author, and a timestamp.

## The big picture

The platform has three systems that work together for identity, access, and policy:

**[Keycloak](https://auth.metosin.net)** handles **authentication** — it's the login system. Users sign in through Keycloak, which issues JWT tokens.

**[OpenFGA](https://openfga.dev)** handles **relationship-based authorization** — it answers "is this user allowed to access this resource?" based on user/team/resource relationships. Managed in [mas-openfga-models](https://github.com/metosin/mas-openfga-models).

**[OPA](https://www.openpolicyagent.org)** (this repo) handles **policy-based authorization** — it answers "is this specific request allowed?" based on request content, context, and rules. OPA evaluates structured inputs (user, teams, tool name, payload size, etc.) against Rego policies and returns allow/deny.

### When to use which

| Question | System | Example |
|----------|--------|---------|
| "Is this user who they say they are?" | Keycloak | JWT validation |
| "Can user X access resource Y?" | OpenFGA | `user:alice` has `allowed_user` on `mcp_tool:search-vectors` |
| "Is this request valid given its context?" | OPA | Payload under size limit, tool not restricted, user in correct team |

OpenFGA and OPA are complementary. A service might check OpenFGA first ("does this user have access to this tool?") and then check OPA ("is this specific invocation allowed given the request context?").

### The full flow for a request

```
1. User logs in via Keycloak -> gets a JWT token
2. User makes a request to your service with the JWT
3. Your service validates the JWT (Keycloak — authentication)
4. Your service checks OpenFGA: "does user:X have relation:Y on object:Z?" (relationship auth)
5. Your service checks OPA: "is this request allowed?" with full context (policy auth)
6. Your service allows or denies the request
```

Steps 4 and 5 are both optional — use whichever makes sense for your use case.

## How it works, end to end

### 1. This repo defines policies in Rego

Policies are organized by team in the `policies/` directory. Each policy package defines `allow` rules:

```rego
package mcp.tool_invocation

default allow := false

allow {
    input.user != ""
    not is_restricted_tool
}
```

### 2. Tests validate policy logic

Tests in `policies_test/` verify that policies behave correctly:

```rego
test_allow_normal_tool {
    tool_invocation.allow with input as {"user": "alice", "teams": ["default"], "tool_name": "search-vectors"}
}
```

### 3. CI deploys to OPA on every push to main

```
git push to main
    -> Woodpecker CI runs `opa test` (catches logic errors)
    -> CI pushes each .rego file to OPA via REST API
    -> OPA is now serving the updated policies
```

### 4. Your service checks policies at runtime

Any service that needs policy evaluation calls the OPA API:

```
POST /v1/data/mcp/tool_invocation
{
  "input": {
    "user": "alice",
    "teams": ["default"],
    "tool_name": "search-vectors"
  }
}
-> {"result": {"allow": true}}
```

## What's in this repo

```
policies/              # Rego policy files, organized by team
  common/common.rego   # Shared helpers (is_authenticated, is_team_member)
  mcp/mcp.rego         # MCP team: tool invocation policies
  demo/demo.rego       # Demo team: request validation policies
policies_test/         # Rego tests
  common_test.rego     # Tests for common helpers
  mcp_test.rego        # Tests for MCP policies
  demo_test.rego       # Tests for demo policies
scripts/               # CI deployment script
.woodpecker.yml        # CI pipeline config
```

## Team Guide

### Adding a new rule to an existing policy

Example: you want to add a rate-limit check to the MCP tool invocation policy.

1. Edit `policies/mcp/mcp.rego` and add your rule
2. Add tests in `policies_test/mcp_test.rego`
3. Run tests locally: `opa test policies/ policies_test/ -v`
4. Push to `main`. CI tests and deploys.

### Creating a new policy for your team

Example: your team needs request validation policies for a new service.

1. Create `policies/myteam/myteam.rego`:
   ```rego
   package myteam.request_validation

   import data.common

   default allow := false

   allow {
       common.is_authenticated
       # your rules here
   }
   ```

2. Create `policies_test/myteam_test.rego`:
   ```rego
   package myteam.request_validation_test

   import data.myteam.request_validation

   test_allow_valid_request {
       request_validation.allow with input as {"user": "alice"}
   }
   ```

3. Run tests: `opa test policies/ policies_test/ -v`
4. Push to `main`.
5. Your service queries: `POST /v1/data/myteam/request_validation`

### Who owns what

| Directory | Team | What it defines |
|-----------|------|-----------------|
| `policies/common/` | Platform | Shared helpers — coordinate before editing |
| `policies/mcp/` | MCP / App teams | Tool invocation rules |
| `policies/demo/` | Demo | Request validation rules |

Edit your team's directory. Coordinate before editing other teams' policies.

## Using OPA in your service

OPA runs in the cluster at `http://opa.opa-system.svc:8181`. No SDK needed — it's a simple HTTP POST.

**Check a policy:**
```
POST http://opa.opa-system.svc:8181/v1/data/mcp/tool_invocation
Content-Type: application/json

{
  "input": {
    "user": "alice",
    "teams": ["default"],
    "tool_name": "search-vectors"
  }
}
-> {"result": {"allow": true}}
```

**Go example:**
```go
type OPAInput struct {
    User     string   `json:"user"`
    Teams    []string `json:"teams"`
    ToolName string   `json:"tool_name"`
}

type OPARequest struct {
    Input OPAInput `json:"input"`
}

type OPAResponse struct {
    Result struct {
        Allow bool `json:"allow"`
    } `json:"result"`
}

func CheckPolicy(ctx context.Context, input OPAInput) (bool, error) {
    body, _ := json.Marshal(OPARequest{Input: input})
    resp, err := http.Post(
        "http://opa.opa-system.svc:8181/v1/data/mcp/tool_invocation",
        "application/json",
        bytes.NewReader(body),
    )
    if err != nil {
        return false, err
    }
    defer resp.Body.Close()

    var result OPAResponse
    json.NewDecoder(resp.Body).Decode(&result)
    return result.Result.Allow, nil
}
```

**The input is whatever your policy expects.** The `input` object is passed directly to the Rego policy as `input`. Design the input schema in your policy, document it, and have your service send the right fields.

## Local development

```bash
# Install OPA: https://www.openpolicyagent.org/docs/latest/#running-opa

# Run all tests
opa test policies/ policies_test/ -v

# Evaluate a policy with sample input
echo '{"user": "alice", "teams": ["default"], "tool_name": "search-vectors"}' | \
  opa eval -d policies/ -I 'data.mcp.tool_invocation.allow'

# Start a local OPA server
opa run --server policies/
# Then query it:
curl -X POST http://localhost:8181/v1/data/mcp/tool_invocation \
  -d '{"input":{"user":"alice","teams":["default"],"tool_name":"search-vectors"}}'
```
