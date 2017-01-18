# A sample Guardfile
# More info at https://github.com/guard/guard#readme

group 'specs', halt_on_fail: true do
  guard :rspec, cmd: 'bundle exec rspec --no-profile --tag ~slow', all_after_pass: true do
    watch(%r{^spec/.+_spec\.rb$})
    watch(%r{^routemaster/(.+)\.rb$})       { |m| "spec/#{m[1]}_spec.rb" }
    watch('spec/spec_helper.rb')            { "spec" }
    watch(%r{^spec/support/(.+)\.rb$})      { "spec" }
    watch(%r{^routemaster/mixins/.+\.rb$})  { "spec" }
  end

  guard :rspec, cmd: 'bundle exec rspec --no-profile --tag slow', all_after_pass: false do
    watch(%r{^spec/.+_spec\.rb$})
    watch(%r{^routemaster/(.+)\.rb$})       { |m| "spec/#{m[1]}_spec.rb" }
    watch('spec/spec_helper.rb')            { "spec" }
    watch(%r{^spec/support/(.+)\.rb$})      { "spec" }
    watch(%r{^routemaster/mixins/.+\.rb$})  { "spec" }
  end
end
