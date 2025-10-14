# Tasks Directory

This directory contains task automation scripts and definitions.

## Structure

```
tasks/
├── aws-tasks.yml              # AWS task definitions
├── cmd/                       # Command scripts
│   └── bucket_s3_create.sh    # S3 bucket creation script
├── .prerequisites_validated   # Runtime validation flag (git-ignored)
└── README.md                  # This file
```

## Task Files (Tracked)

### `aws-tasks.yml`
Task definitions for AWS operations. Used by task runners to automate AWS workflows.

### `cmd/bucket_s3_create.sh`
Executable script for creating and configuring S3 buckets.

## Runtime Files (Git-Ignored)

### `.prerequisites_validated`
Validation status file created by `../validate-prerequisites.sh`. This file:
- Confirms all prerequisites are met
- Contains timestamp and component status
- Is automatically managed by validation scripts
- Should not be committed to git

## Usage

### Running Tasks

Tasks are typically executed via the root Taskfile:

```shell
# From project root
task aws:create-bucket
```

### Adding New Tasks

1. Add task definition to appropriate YAML file
2. Add executable scripts to `cmd/` directory if needed
3. Document in this README
4. Ensure runtime/temporary files are added to `.gitignore`

## What's Tracked in Git

✅ **Tracked:**
- Task definition files (`*.yml`)
- Command scripts (`cmd/*.sh`)
- Documentation (`README.md`)
- Directory structure

❌ **Not Tracked:**
- `.prerequisites_validated` (runtime state)
- Temporary files
- Build artifacts
- Any other runtime-generated content

## See Also

- [TASKS_README.md](../TASKS_README.md) - Detailed documentation about the validation flag
- [Taskfile.yml](../Taskfile.yml) - Main task definitions
- [validate-prerequisites.sh](../validate-prerequisites.sh) - Prerequisites validation script
