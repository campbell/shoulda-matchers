module ModelBuilder
  def self.included(example_group)
    example_group.class_eval do
      before do
        @created_tables ||= []
        @defined_models ||= []
      end

      after do
        drop_created_tables
        remove_models
      end
    end
  end

  def create_table(table_name, options = {}, &block)
    connection = ActiveRecord::Base.connection

    begin
      connection.execute("DROP TABLE IF EXISTS #{table_name}")
      connection.create_table(table_name, options, &block)
      @created_tables << table_name
      connection
    rescue Exception => e
      connection.execute("DROP TABLE IF EXISTS #{table_name}")
      raise e
    end
  end

  def define_model_class(class_name, &block)
    @defined_models << class_name
    define_class(class_name, ActiveRecord::Base, &block)
  end

  def define_active_model_class(class_name, options = {}, &block)
    define_class(class_name) do
      include ActiveModel::Validations

      options[:accessors].each do |column|
        attr_accessor column.to_sym
      end

      if block_given?
        class_eval(&block)
      end
    end
  end

  def define_model(name, columns = {}, &block)
    class_name = name.to_s.pluralize.classify
    table_name = class_name.tableize
    table_block = lambda do |table|
      columns.each do |name, type|
        table.column name, type
      end
    end

    if columns.key?(:id) && columns[:id] == false
      columns.delete(:id)
      create_table(table_name, :id => false, &table_block)
    else
      create_table(table_name, &table_block)
    end

    define_model_class(class_name, &block)
  end

  def drop_created_tables
    connection = ActiveRecord::Base.connection

    @created_tables.each do |table_name|
      connection.execute("DROP TABLE IF EXISTS #{table_name}")
    end
  end

  def remove_models
    @defined_models.each do |model_name|
      if Object.const_defined?(model_name.to_sym)
        Object.send(:remove_const, model_name.to_sym)
      end
    end
  end
end

RSpec.configure do |config|
  config.include ModelBuilder
end
