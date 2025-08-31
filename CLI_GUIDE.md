# PROMTOK Command Line Interface (CLI) Guide

The PROMTOK CLI provides powerful command-line tools for bulk document processing, user management, and system administration. The CLI features **direct processing** with real-time progress feedback, bypassing the background queue system for immediate results.

## Quick Start

PROMTOK provides convenient wrapper scripts for different platforms:

### Linux/macOS
```bash
# Make the script executable (first time only)
chmod +x promtok-cli.sh

# Show available commands
./promtok-cli.sh help

# Example: Create a user and ingest documents
./promtok-cli.sh create-user researcher mypass123
./promtok-cli.sh ingest researcher ./documents
```

### Windows PowerShell
```powershell
# Show available commands
.\promtok-cli.ps1 help

# Example: Create a user and ingest documents
.\promtok-cli.ps1 create-user researcher mypass123
.\promtok-cli.ps1 ingest researcher .\documents
```

### Windows Command Prompt
```cmd
REM Show available commands
promtok-cli.bat help

REM Example: Create a user and ingest documents
promtok-cli.bat create-user researcher mypass123
promtok-cli.bat ingest researcher .\documents
```

## Key Features

- **Direct Processing**: Documents are processed immediately with live feedback
- **Real-time Progress**: See each processing step with timestamps
- **No Queue**: Bypasses the background processor for immediate results
- **Multi-format Support**: Handles PDF, Word (docx, doc), and Markdown (md, markdown) files
- **GPU Control**: Specify which GPU device to use for processing
- **Flexible Organization**: Documents added to user library, can be organized into groups
- **Auto-cleanup**: Option to delete source files after successful processing

## Available Commands

### User Management

#### create-user
Create a new user account.

```bash
./promtok-cli.sh create-user <username> <password> [options]
```

**Options:**
- `--full-name "Name"`: Set the user's full name
- `--admin`: Create an admin user

**Examples:**
```bash
# Create a regular user
./promtok-cli.sh create-user researcher mypass123 --full-name "Research User"

# Create an admin user
./promtok-cli.sh create-user admin adminpass --admin --full-name "Administrator"
```

#### list-users
List all users in the system (admin only).

```bash
./promtok-cli.sh list-users
```

### Document Group Management

#### create-group
Create a document group for organizing documents.

```bash
./promtok-cli.sh create-group <username> <group_name> [options]
```

**Options:**
- `--description "Description"`: Add a description for the group

**Example:**
```bash
./promtok-cli.sh create-group researcher "AI Papers" --description "Machine Learning Research"
```

#### list-groups
List document groups.

```bash
./promtok-cli.sh list-groups [options]
```

**Options:**
- `--user <username>`: List groups for a specific user only

**Examples:**
```bash
# List all groups (admin view)
./promtok-cli.sh list-groups

# List groups for a specific user
./promtok-cli.sh list-groups --user researcher
```

### Document Processing

#### ingest
Process documents directly with live feedback. This is the primary command for adding documents to PROMTOK.

```bash
./promtok-cli.sh ingest <username> <document_directory> [options]
```

**Options:**
- `--group <group_id>`: Add documents to a specific group
- `--force-reembed`: Force re-processing of existing documents
- `--device <device>`: Specify GPU device (e.g., cuda:0, cuda:1, cpu)
- `--delete-after-success`: Delete source files after successful processing
- `--batch-size <num>`: Control parallel processing (default: 5)

**Supported File Types:**
- PDF files (`.pdf`)
- Word documents (`.docx`, `.doc`)
- Markdown files (`.md`, `.markdown`)

**Examples:**
```bash
# Basic ingestion (documents added to user library)
./promtok-cli.sh ingest researcher ./documents

# Add to specific group
./promtok-cli.sh ingest researcher ./documents --group abc123-def456

# Process with specific GPU
./promtok-cli.sh ingest researcher ./documents --device cuda:0

# Force re-processing and delete after success
./promtok-cli.sh ingest researcher ./documents --force-reembed --delete-after-success

# Process with larger batch size for faster processing
./promtok-cli.sh ingest researcher ./documents --batch-size 10
```

**Processing Workflow:**
1. Validates document directory and counts supported files
2. Converts documents to Markdown format
3. Extracts metadata (title, authors, year, journal)
4. Chunks documents into overlapping paragraphs
5. Generates embeddings using BGE-M3 model
6. Stores in ChromaDB vector store and metadata database
7. Shows real-time progress with timestamps for each step

#### status
Check document processing status.

```bash
./promtok-cli.sh status [options]
```

**Options:**
- `--user <username>`: Check status for specific user
- `--group <group_id>`: Check status for specific group

**Examples:**
```bash
# Check all documents (admin view)
./promtok-cli.sh status

# Check status for specific user
./promtok-cli.sh status --user researcher

# Check status for specific group
./promtok-cli.sh status --user researcher --group abc123-def456
```

#### cleanup
Remove documents that failed to process or have a specific status. This command helps you clean up your database by removing documents that couldn't be processed successfully.

```bash
./promtok-cli.sh cleanup [options]
```

**Options:**
- `--user <username>`: Only clean up documents for a specific user
- `--status <status>`: Target documents with this status (default: "failed")
- `--group <group_id>`: Only clean up documents in a specific group
- `--confirm`: Skip the confirmation prompt

**What it does:**
1. Finds all documents matching your criteria
2. Shows a summary of what will be deleted
3. Asks for confirmation (unless --confirm is used)
4. Deletes the database records
5. Removes associated files from disk

**Examples:**
```bash
# Clean up all failed documents (asks for confirmation)
./promtok-cli.sh cleanup --status failed

# Clean up failed documents without confirmation
./promtok-cli.sh cleanup --status failed --confirm

# Clean up error documents for a specific user
./promtok-cli.sh cleanup --user researcher --status error

# Clean up failed documents in a specific group
./promtok-cli.sh cleanup --group abc123 --status failed
```

#### cleanup-cli
Remove documents that got stuck during CLI processing. This is useful when you interrupt document ingestion (like pressing Ctrl+C) and documents are left in a "cli_processing" state.

```bash
./promtok-cli.sh cleanup-cli [options]
```

**Options:**
- `--dry-run`: Show what would be deleted without actually deleting anything
- `--force`: Skip the confirmation prompt

**What it does:**
1. Finds all documents stuck with "cli_processing" status
2. Shows detailed information about each stuck document
3. Calculates total disk space that will be freed
4. Asks for confirmation (unless --force is used)
5. Deletes documents and all associated files:
   - Raw uploaded files
   - Generated markdown files
   - Vector store embeddings
   - Document group associations

**Examples:**
```bash
# Check what documents are stuck (dry run)
./promtok-cli.sh cleanup-cli --dry-run

# Clean up stuck documents (asks for confirmation)
./promtok-cli.sh cleanup-cli

# Force cleanup without confirmation
./promtok-cli.sh cleanup-cli --force
```

**When to use each command:**
- Use `cleanup` when documents have failed processing and you want to remove them
- Use `cleanup-cli` when you interrupted a CLI ingestion and documents are stuck

### Document Search

#### search
Search through documents for a specific user.

```bash
./promtok-cli.sh search <username> <query> [options]
```

**Options:**
- `--limit <num>`: Limit number of results (default: 10)

**Example:**
```bash
./promtok-cli.sh search researcher "machine learning" --limit 5
```

### Database Management

#### reset-db
Reset all databases and document files. **CRITICAL**: All databases must be reset together to maintain data consistency.

```bash
./promtok-cli.sh reset-db [options]
```

**Options:**
- `--backup`: Create timestamped backups before reset
- `--force`: Skip confirmation prompts (DANGEROUS!)
- `--stats`: Show database statistics only (don't reset)
- `--check`: Check data consistency across databases only

**What Gets Reset:**
- Main application database (users, chats, documents)
- AI researcher database (extracted metadata)
- ChromaDB vector store (embeddings and chunks)
- All document files (PDFs, markdown, metadata)

**Examples:**
```bash
# Show current database statistics
./promtok-cli.sh reset-db --stats

# Check data consistency
./promtok-cli.sh reset-db --check

# Reset with backup
./promtok-cli.sh reset-db --backup

# Force reset without confirmation (DANGEROUS!)
./promtok-cli.sh reset-db --force
```

## Direct Docker Commands

For advanced users, you can also run CLI commands directly with Docker Compose:

```bash
# General format
docker compose --profile cli run --rm cli python cli_ingest.py [command] [options]

# Examples
docker compose --profile cli run --rm cli python cli_ingest.py create-user myuser mypass
docker compose --profile cli run --rm cli python cli_ingest.py list-groups
docker compose --profile cli run --rm cli python cli_ingest.py ingest myuser GROUP_ID /app/pdfs
```

## Directory Structure

When using the CLI, documents should be placed in the appropriate directories:

```
promtok/
├── documents/       # Recommended directory for all document types
├── pdfs/           # Legacy directory (still supported)
└── ...
```

The CLI scripts automatically map your local directories to the container paths:
- `./documents` → `/app/documents`
- `./pdfs` → `/app/pdfs`

## Tips and Best Practices

1. **Document Organization**: Create groups before ingesting documents for better organization
2. **Batch Processing**: Use `--batch-size` to control memory usage and processing speed
3. **GPU Selection**: Use `--device` to specify GPU for multi-GPU systems
4. **Error Recovery**: Use `cleanup` command to remove failed documents before re-processing
5. **Regular Backups**: Use `reset-db --backup` before major operations

## Troubleshooting

### Common Issues

**Docker not running:**
```bash
# Start Docker services
docker compose up -d backend
```

**Permission denied:**
```bash
# Make script executable
chmod +x promtok-cli.sh
```

**Out of memory:**
```bash
# Reduce batch size
./promtok-cli.sh ingest user ./docs --batch-size 2
```

**GPU not available:**
```bash
# Use CPU processing
./promtok-cli.sh ingest user ./docs --device cpu
```

### Getting Help

For detailed help on any command:
```bash
./promtok-cli.sh help
./promtok-cli.sh <command> --help
```

## Performance Considerations

- **Batch Size**: Higher batch sizes process faster but use more memory
- **GPU vs CPU**: GPU processing is 10-20x faster for embeddings
- **Document Size**: Large PDFs may take several minutes to process
- **Network**: First run downloads models (~2GB), subsequent runs use cache
