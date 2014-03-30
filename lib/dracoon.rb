#! /usr/bin/ruby

module Dracoon

    load 'dracoon_nodes.rb'
    load 'dracoon_sqlite.rb'

    require 'treetop'

    class DracoonParser
        @parser
        @writer

        public
        def initialize
            Treetop.load 'dracoon'
            @parser = DracoonGrammarParser.new
            @writer = Dracoon::SQLiteWriter.new
        end

        def processFile(path)
            # file = File.open 'test2.gb'
            # data = file.read
            file = File.open path
            data = file.read

            # puts data
            ast = @parser.parse data
            if ast then
                ast.cutdown
                #puts '==> RESULTS:'
                # puts ast.inspect
                puts '==> Writing gamebook file...'
                @writer.writeAST(ast, nil)
            else
                @parser.failure_reason =~ /^(Expected .+) after/m
                puts "#{$1.gsub("\n", '$NEWLINE')}:"
                puts data.lines.to_a[@parser.failure_line - 1]
                puts "#{'~' * (@parser.failure_column - 1)}^"
            end
        end

        def processDirectory(path)
            Dir.foreach(path) do |f|
                next if f == '.' or f == '..' or File.extname(f) != '.gbook'
                if File::directory? f
                    processDirectory(path + '/' + f)
                elsif File::file? f
                    puts "Processing file #{f}"
                    processFile f
                end
            end
        end

    end
end

dracoonParser = Dracoon::DracoonParser.new
dracoonParser.processDirectory(".")
