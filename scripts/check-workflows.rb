# Structural checks of the GitHub Actions workflows: the release keeps its
# security boundaries. Run: ruby scripts/check-workflows.rb
require "yaml"

$fails = 0
def fail!(msg) = (puts("FAIL #{msg}"); $fails += 1)
def ok(msg) = puts("ok   #{msg}")

def load(path)
  # Psych reads the key `on:` as true.
  YAML.safe_load(File.read(path), aliases: false).transform_keys { |k| k == true ? "on" : k }
end

ci = load(".github/workflows/ci.yml")
rel = load(".github/workflows/release.yml")
pinned = /\A[\w.-]+\/[\w.\/-]+@[0-9a-f]{40}\z/

[[".github/workflows/ci.yml", ci], [".github/workflows/release.yml", rel]].each do |path, w|
  w["permissions"] == { "contents" => "read" } ? ok("#{path}: default permissions read-only") : fail!("#{path}: top-level permissions must be contents: read")
  w["jobs"].each do |name, job|
    (job["steps"] || []).each do |s|
      next unless s["uses"] && !s["uses"].start_with?("./")
      s["uses"].match?(pinned) || fail!("#{path}: #{name}: #{s["uses"]} is not pinned to a commit SHA")
    end
  end
end
ok("every action is pinned to a commit SHA") if $fails.zero?

on = rel["on"]
(on.keys == ["push"] && on["push"] == { "tags" => ["v*"] }) ? ok("release runs only on v* tag pushes") : fail!("release.yml must run only on push of tags v*")
ci["on"].key?("workflow_call") ? ok("ci.yml is reusable") : fail!("ci.yml must be callable (workflow_call)")
gate = ci["jobs"]["ci-gate"]
missing = ci["jobs"].keys - ["ci-gate"] - Array(gate && gate["needs"])
missing.empty? ? ok("ci-gate needs every CI job") : fail!("ci-gate does not need #{missing.join(", ")}")
rel["jobs"]["ci"]&.dig("uses") == "./.github/workflows/ci.yml" ? ok("release runs the full CI") : fail!("release.yml must run ci.yml as job ci")

secret_re = /secrets\./
tap_if = "${{ !contains(github.ref_name, '-') }}"
rel["jobs"].each do |name, job|
  next if name == "ci"
  Array(job["needs"]).include?("ci") ? nil : fail!("job #{name} does not need ci")
  steps = job["steps"] || []
  builds = steps.any? { |s| s.dig("with", "stages").to_s.match?(/archive/) }
  if builds
    job["permissions"] == { "contents" => "read" } ? ok("#{name}: packages with contents: read only") : fail!("#{name}: packaging job must have only contents: read")
    job["environment"].nil? ? nil : fail!("#{name}: packaging job must not use an environment")
    steps.to_yaml.match?(secret_re) ? fail!("#{name}: packaging job must not use secrets") : ok("#{name}: no secrets")
  end
  steps.each do |s|
    next unless s.to_yaml.match?(secret_re)
    job["environment"] == "release" || fail!("#{name}: step #{s["name"]} uses a secret outside environment release")
    s["if"] == tap_if || fail!("#{name}: step #{s["name"]} uses a secret without #{tap_if} (prereleases get no tap token)")
  end
  names = steps.map { |s| s["name"].to_s }
  publish = steps.index { |s| s.dig("with", "command") == "release" }
  next unless publish
  verify = steps.index { |s| s["run"].to_s.include?("verify-dist.sh") }
  (verify && verify < publish) ? ok("#{name}: verify-dist runs before publishing") : fail!("#{name}: verify-dist must run before the release step")
  attest = steps.index { |s| s["uses"].to_s.start_with?("actions/attest-build-provenance@") }
  (attest && attest < publish) ? ok("#{name}: attestation before publishing") : fail!("#{name}: attest before the release step")
  rehearse = names.index("Rehearse the formula and tap pull request (read-only)")
  (rehearse && rehearse < publish) ? ok("#{name}: tap rehearsal before publishing") : fail!("#{name}: tap rehearsal must run before the release step")
  perms = job["permissions"]
  perms == { "contents" => "write", "id-token" => "write", "attestations" => "write" } ? ok("#{name}: publish permissions exact") : fail!("#{name}: unexpected permissions #{perms}")
  job["environment"] == "release" ? ok("#{name}: environment release") : fail!("#{name}: must run in environment release")
end

puts
abort("#{$fails} workflow check(s) failed") if $fails.positive?
puts "workflow checks passed"
