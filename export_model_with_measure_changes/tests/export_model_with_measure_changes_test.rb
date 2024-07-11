require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ExportModelWithMeasureChangesTest < Minitest::Test
  def setup
    # Create an instance of the measure
    @measure = ExportModelWithMeasureChanges.new

    # Create the directory structure
    @test_dir = Dir.mktmpdir
    @resources_dir = File.join(@test_dir, 'resources')
    @run_dir = File.join(@resources_dir, 'run')
    @measure_source_dir = File.join(@resources_dir, 'measures')
    @measure_run_dir = File.join(@measure_source_dir, 'export_model_with_measure_changes')

    [@resources_dir, @run_dir, @measure_source_dir, @measure_run_dir].each do |dir|
      Dir.mkdir(dir)
    end

    # Create a dummy parent model file in the parent directory
    @model = OpenStudio::Model::Model.new
    @parent_dir = File.expand_path('../../../', @measure_run_dir)
    Dir.mkdir(@parent_dir) unless Dir.exist?(@parent_dir)
    @parent_model_path = File.join(@parent_dir, 'parent_model.osm')
    @model.save(OpenStudio::Path.new(@parent_model_path), true)

    # Create and save a dummy in.osm OpenStudio model in the run directory    
    @in_osm_path = File.join(@run_dir, 'in.osm')
    @model.save(OpenStudio::Path.new(@in_osm_path), true)

    # Create an instance of a runner
    @runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # Manually set the root directory in user arguments
    @runner.setLastOpenStudioModelPath(OpenStudio::Path.new(@in_osm_path))

    # Ensure the working directory is set to the measure run directory
    Dir.chdir(@measure_run_dir)
  end

  # def teardown
  #   # Ensure all files and directories are removed before removing the test directory
  #   FileUtils.rm_rf(@test_dir) if Dir.exist?(@test_dir)
  # end

  def test_arguments
    # Get arguments from the measure
    arguments = @measure.arguments(nil)
    assert_equal(5, arguments.size)
    assert_equal('custom_name', arguments[0].name)
    assert_equal('destination_dir', arguments[1].name)
    assert_equal('custom_path', arguments[2].name)
    assert_equal('use_versioning', arguments[3].name)
    assert_equal('version_suffix', arguments[4].name)
  end

  def test_default_argument_values
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(@measure.arguments(nil))

    custom_name = argument_map['custom_name'].clone
    assert(!custom_name.hasDefaultValue || custom_name.defaultValueAsString == '')

    destination_dir = argument_map['destination_dir'].clone
    assert(destination_dir.hasDefaultValue && destination_dir.defaultValueAsString == 'Reports Directory')

    custom_path = argument_map['custom_path'].clone
    assert(!custom_path.hasDefaultValue || custom_path.defaultValueAsString == '')

    use_versioning = argument_map['use_versioning'].clone
    assert(use_versioning.hasDefaultValue && use_versioning.defaultValueAsString == 'false')

    version_suffix = argument_map['version_suffix'].clone
    assert(version_suffix.hasDefaultValue && version_suffix.defaultValueAsString == '_v')
  end

  def test_setting_custom_arguments
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(@measure.arguments(nil))

    custom_name = argument_map['custom_name'].clone
    assert(custom_name.setValue('custom_model_name'))
    assert_equal('custom_model_name', custom_name.valueAsString)

    destination_dir = argument_map['destination_dir'].clone
    assert(destination_dir.setValue('Custom Path'))
    assert_equal('Custom Path', destination_dir.valueAsString)

    custom_path = argument_map['custom_path'].clone
    custom_export_path = File.join(@test_dir, 'custom_export')
    Dir.mkdir(custom_export_path)
    assert(custom_path.setValue(custom_export_path))
    assert_equal(custom_export_path, custom_path.valueAsString)

    use_versioning = argument_map['use_versioning'].clone
    assert(use_versioning.setValue(true))
    assert_equal('true', use_versioning.valueAsString)

    version_suffix = argument_map['version_suffix'].clone
    assert(version_suffix.setValue('_v2'))
    assert_equal('_v2', version_suffix.valueAsString)
  end

  def test_measure_with_debug_output
    # Create a new argument map
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(@measure.arguments(nil))

    # Set arguments to default values
    custom_name = argument_map['custom_name'].clone
    assert(custom_name.setValue(''))
    argument_map['custom_name'] = custom_name

    destination_dir = argument_map['destination_dir'].clone
    assert(destination_dir.setValue('Reports Directory'))
    argument_map['destination_dir'] = destination_dir

    custom_path = argument_map['custom_path'].clone
    assert(custom_path.setValue(''))
    argument_map['custom_path'] = custom_path

    use_versioning = argument_map['use_versioning'].clone
    assert(use_versioning.setValue(false))
    argument_map['use_versioning'] = use_versioning

    version_suffix = argument_map['version_suffix'].clone
    assert(version_suffix.setValue('_v'))
    argument_map['version_suffix'] = version_suffix

    # Run the measure
    puts "Running Measure in Directory: #{Dir.pwd}"
    puts "Parent Model Path: #{@parent_model_path}"

    @measure.run(@runner, argument_map)
    result = @runner.result
    show_output(result)
    assert_equal('Success', result.value.valueName)

    # Check that the file was copied and renamed correctly
    expected_path = File.join(@test_dir, 'reports', 'parent_model_wMeasures.osm')
    assert(File.exist?(expected_path))
  end
end
