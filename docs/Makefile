# Minimal makefile for Sphinx documentation
#

# You can set these variables from the command line.
SPHINXOPTS    =
SPHINXBUILD   = sphinx-build
SPHINXPROJ    = kiwi
SOURCEDIR     = source
BUILDDIR      = build

# Put it first so that "make" without argument is like "make help".
help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)
	@echo "  swift-api   to generate Swift public interface (.swiftinterface)"

# Generate Swift public interface from the compiled module.
swift-api:
	cd .. && swift build -Xswiftc -emit-module-interface-path \
		-Xswiftc docs/$(BUILDDIR)/KiwiSolver.swiftinterface \
		-Xswiftc -enable-library-evolution \
		--target KiwiSolver 2>/dev/null; true
	@echo "Wrote $(BUILDDIR)/KiwiSolver.swiftinterface"

.PHONY: help swift-api Makefile

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option.  $(O) is meant as a shortcut for $(SPHINXOPTS).
%: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)
