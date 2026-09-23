#!/usr/bin/env bash
set -e

echo "============================================="
echo " [SECURITY GATE] Running DevSecOps Scans"
echo "============================================="

FAILED=0

# 1. SECRET SCANNING (Scan both files and Git tree)
echo "[1/3] Scanning for hardcoded secrets with Gitleaks..."
if command -v gitleaks &> /dev/null; then
    # --no-git scans the actual file tree directly, catching uncommitted secrets!
    if ! gitleaks detect --source . --config security/gitleaks.toml --no-git --verbose --redact; then
        echo ">> [SECURITY GATE FAIL] Gitleaks detected hardcoded secrets!"
        FAILED=1
    else
        echo ">> Secret scan PASSED: No credentials committed."
    fi
else
    echo "WARNING: gitleaks not installed on agent. Running fallback regex scan..."
    if grep -r -E "(password|secret|apikey)\s*=\s*['\"][a-zA-Z0-9_\-]{8,}['\"]" backend/ --exclude="appsettings.Development.json"; then
        echo ">> [CRITICAL FAIL] Potential secret found in repository!"
        FAILED=1
    fi
fi

# 2. SAST (Static Application Security Testing)
echo "[2/3] Running SAST Code Quality & Vulnerability Scan..."
if command -v semgrep &> /dev/null; then
    if ! semgrep scan --config "p/security-audit" --error --no-git-ignore --exclude="node_modules" --exclude="docs" backend/; then
        echo ">> [SECURITY GATE FAIL] Semgrep detected security vulnerabilities!"
        FAILED=1
    else
        echo ">> SAST scan PASSED."
    fi
else
    echo ">> [SKIP] Semgrep not installed or unavailable."
fi

# 3. SCA / DEPENDENCY VULNERABILITY SCANNING
echo "[3/3] Scanning dependencies for known CVEs..."
# Backend NuGet Check
if [ -f "backend/ProductAPI.csproj" ]; then
    echo ">> Running dotnet list package vulnerability check..."
    VULN_OUTPUT=$(dotnet list backend/ProductAPI.csproj package --vulnerable --include-transitive 2>&1 || true)
    echo "$VULN_OUTPUT"
    if echo "$VULN_OUTPUT" | grep -iE "has the following vulnerable packages|Critical|High"; then
        echo ">> [SECURITY GATE FAIL] Critical/High severity dependency vulnerabilities found in NuGet packages!"
        FAILED=1
    fi
fi

# Frontend npm Audit Check
if [ -d "frontend" ] && [ -f "frontend/package.json" ]; then
    echo ">> Running npm audit dependency check..."
    cd frontend
    if ! npm audit --audit-level=high; then
        echo ">> [SECURITY GATE FAIL] Critical/High severity vulnerabilities found in npm packages!"
        FAILED=1
    fi
    cd ..
fi

if [ $FAILED -ne 0 ]; then
    echo "============================================="
    echo " ❌ [SECURITY GATE FAILED] Critical issues detected!"
    echo " Deployment aborted by DevSecOps Security Gate."
    echo "============================================="
    exit 1
fi

echo "============================================="
echo " ✅ [SECURITY GATE] All security checks PASSED!"
echo "============================================="