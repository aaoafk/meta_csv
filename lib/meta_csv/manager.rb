module MetaCsv
  class Manager
    Standardizer = if RUBY_VERSION >= "3.2"
                     Data.define(:source, :old_headers, :new_headers, :inferred_encoding, :standardizing_functions, :csv_chunks)
                   else
                     Struct.new(:source, :old_headers, :new_headers, :inferred_encoding, :standardizing_functions, :csv_chunks)
                   end

    # TODO: Remove these constants

    LEDGER_LIVE_CSV_SOURCE = :LEDGER_LIVE_CSV_SOURCE
    COIN_TRACKER_CSV_SOURCE = :COIN_TRACKER_CSV_SOURCE
    TURBO_TAX_CSV_SOURCE = :TURBO_TAX_CSV_SOURCE
    OTHER_CSV_SOURCE = :OTHER_CSV_SOURCE
    INFER = :INFER

    class << self
      #########################################################################
      #          The definition in the schema file hooks into this method     #
      #########################################################################
      attr_accessor :user_schema

      def validation_schema
        @user_schema = yield
      end

      def seesaw_ractor!(collection:, method:)
        collection.each do |el|
          el.rows.send method
        end
      end

      # TODO: Abstract `file_path` to IO? That just represents a source CSV
      def run(file_path:, transformations:, schema_file_path:, &block)
        raise 'No source CSV provided' unless File.exist? file_path
        raise 'Transformations file doesnt exist' unless File.exist? transformations

        # => Blueprint digests the `define_column` DSL.
        blueprint = Blueprint.new(transformations_file: transformations)
        source = INFER

        if block_given?
          # => `Dry::Schema from the block`
          user_schema = yield
          raise 'Invalid Schema' unless user_schema.is_a? Dry::Schema
        else
          # => Dry::Schema hooks into `validation_schema` method above
          if !schema_file_path.empty?
            eval(File.open(schema_file_path).read)
            source = OTHER_CSV_SOURCE
          end
        end

        new_headers = Blueprint.new_column_names

        if !source in LEDGER_LIVE_CSV_SOURCE | COIN_TRACKER_CSV_SOURCE | TURBO_TAX_CSV_SOURCE | OTHER_CSV_SOURCE | INFER
          raise 'Invalid CSV Source error'
        end

        result = Parser.new(file: file_path)

        ###########################################################################
        #     The standardizer wraps information we might need                    #
        ###########################################################################
        standardizer = Standardizer.new(
          old_headers: result.csv_chunks[0].rows.headers,
          new_headers:,
          source:,
          inferred_encoding: result.inferred_encoding,
          standardizing_functions: transformation_builder.standard_transformations,
          csv_chunks: result.csv_chunks
        )

        #########################################################################
        #    Ractors can't invoke `!' methods, i.e. setters and other things    #
        #########################################################################
        seesaw_ractor!(collection: standardizer.csv_chunks, method: :by_col!)
        mean_types_for_csv_row_chunks = ::Parallel.map(standardizer.csv_chunks, in_ractors: OS.cores, ractor: [Inferencer, :infer_type_for_chunk], progress: true)
        seesaw_ractor!(collection: standardizer.csv_chunks, method: :by_row!)

        # The master_schema has the inferred types across all chunks.
        Inferencer.merge_inferred_types mean_types_for_csv_row_chunks

        #########################################################################
        #         ValCoerc will coerce values using the inferred schema         #
        #########################################################################
        blueprint = user_schema if source == OTHER_CSV_SOURCE
        blueprint = Inferencer.master_schema if source == INFER

        ap blueprint
        sb = SchemaBuilder.new(headers: standardizer.old_headers, blueprint:)
        sb.build_schema
        ap sb.schema, indent: -2, class: Dry::Schema::Params
        exit

        coerced_csv = ValCoerc.new.run(csv_chunks:, user_schema:)

        # coerced_csv needs to be a CSV table?
        transformer = Transformer.new(meta_csv: coerced_csv, standardizer: standardizer)
        transformed_csv = transformer.run

        ap transformed_csv
        File.open((File.join(Dir.home, "transformed_csv_#{Time.now.strftime("%Y-%m-%d_%H_%M_%S")}.csv")), 'w') do |f|
          f.write transformed_csv
        end
      end
    end
  end
end
