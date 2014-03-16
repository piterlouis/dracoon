
require 'sqlite3'
require 'uglifier'

load 'dracoon_nodes.rb'


module Dracoon

    class SQLiteWriter
        include DracoonGrammar

        TYPE_CONTENT = 1
        TYPE_WORD    = 2
        TYPE_KEYWORD = 3
        TYPE_LINK    = 4
        TYPE_IFTAG   = 5
        TYPE_JSEXPR  = 6

        @db = nil
        @currentModule = nil
        @currentScene = nil
        @currentPassage = nil
        @currentItem = nil


        def initialize
            File::delete('gamebook.db') if File::exist? 'gamebook.db'
            @db = SQLite3::Database.new('gamebook.db')
            self.createTables
        end

        def writeModule(node)
            @db.execute("insert into Modules (name) values ('')")
            node.oid = @db.last_insert_row_id
            @currentModule = node
            node.elements.each do |e|
                if e.is_a? HeaderNode
                    self.writeHeader(e, node)
                elsif e.is_a? SceneNode
                    self.writeScene(e, node)
                elsif e.is_a? ItemNode
                    self.writeItem(e, node)
                end
                @currentScene = nil
                @currentItem  = nil
            end
        end

        def writeScene(node, parent)
            @db.execute("insert into Scenes (idModule) values (?)", parent.oid)
            node.oid = @db.last_insert_row_id
            @currentScene = node
            node.elements.each do |e|
                if e.is_a? HeaderNode
                    self.writeHeader(e, node)
                elsif e.is_a? PassageNode
                    self.writePassage(e, node)
                end
                @currentPassage = nil
            end
        end

        def writePassage(node, parent)
            @db.execute("insert into Passages (idScene) values (?)", parent.oid)
            node.oid = @db.last_insert_row_id
            @currentPassage = node
            node.elements.each do |e|
                if e.is_a? HeaderNode
                    self.writeHeader(e, node)
                elsif e.is_a? ContentNode
                    self.writeContent(e, nil)
                    @db.execute("update Passages set idNode=? where oid=?", e.oid, node.oid) unless e.oid.nil?
                elsif e.is_a? ActionNode
                    self.writeAction(e, node)
                end
            end
        end

        def writeItem(node, parent)
            @db.execute("insert into Items (idModule) values (?)", parent.oid)
            node.oid = @db.last_insert_row_id
            @currentItem = node
            node.elements.each do |e|
                if e.is_a? HeaderNode
                    self.writeHeader(e, node)
                elsif e.is_a? ContentNode
                    self.writeContent(e, nil)
                    @db.execute("update Items set idNode=? where oid=?", e.oid, node.oid) unless e.oid.nil?
                elsif e.is_a? ActionNode
                    self.writeAction(e, node)
                end
            end
        end

        def writeHeader(node, parent)
            entityName = nil
            name = nil
            summary = nil
            jscode = nil
            node.elements.each do |e|
                if e.is_a? IdentifierNode
                    name = e.text_value
                elsif e.is_a? SummaryNode
                    summary = e.text_value
                elsif e.is_a? ScriptNode
                    jscode = e.text_value
                end
            end

            if parent.is_a? ModuleNode
                entityName = 'Modules'
                jscode = "var m#{parent.oid} = {#{jscode}} ;"
            elsif parent.is_a? SceneNode
                entityName = 'Scenes'
                jscode = "var s#{parent.oid} = {#{jscode}} ;"
            elsif parent.is_a? PassageNode
                entityName = 'Passages'
                jscode = "var p#{parent.oid} = {#{jscode}} ;"
            elsif parent.is_a? ItemNode
                entityName = 'Items'
                jscode = "var o#{parent.oid} = {#{jscode}} ;"
            end
            jscode = Uglifier.compile(jscode, :mangle => false)
            query = "update #{entityName} set name=?, summary=?, jscode=? where oid=?"
            @db.execute(query, name, summary, jscode, parent.oid)
        end

        def writeContent(node, parent)
            if parent.nil?
                @db.execute("insert into Nodes (type) values (?)", TYPE_CONTENT)
            else
                @db.execute("insert into Nodes (idParent, type) values (?, ?)", parent.oid, TYPE_CONTENT)
            end
            node.oid = @db.last_insert_row_id
            index = 1
            node.elements.each do |e|
                if e.is_a? WordNode or e.is_a? PunctuationNode or e.is_a? NewLineNode or e.is_a? EndParagraphNode
                    self.writeWord(e, node)
                elsif e.is_a? LinkNode
                    self.writeLink(e, node)
                elsif e.is_a? IfTagNode
                    self.writeIfTag(e, node)
                end
                @db.execute("update Nodes set sort = ? where oid = ?", index, e.oid)
                index = index + 1
            end
        end

        def writeAction(node, parent)
            keyword = nil
            name = nil
            jscode = nil
            idAction = nil
            node.elements.each do |e|
                if e.is_a? KeywordNode
                    keyword = e.text_value
                elsif e.is_a? ScriptNode
                    jscode = e.text_value
                end
            end
            name = actionNameForCurrentContext(keyword)
            idAction = @db.get_first_row("select oid from Actions where name = ?", name)
            begin
                jscode = "var #{name} = {#{jscode}} ;"
                jscode = Uglifier.compile(jscode, :mangle => false)
            rescue
                puts 'Error trying to uglifying code: ' + jscode
            end

            if idAction.nil? then
                puts "Warning: Definition of action [#{keyword}] without associated link."
                @db.execute("insert into Actions (name, jscode) values (?, ?)", name, jscode)
                idAction = @db.last_insert_row_id
            else
                @db.execute("update Actions set jscode = ? where oid = ?", jscode, idAction)
            end
            node.oid = idAction
        end

        def writeLink(node, parent)
            @db.execute("insert into Nodes (idParent, type) values (?, ?)", parent.oid, TYPE_LINK)
            node.oid = @db.last_insert_row_id
            keyword = nil
            firstWord = nil
            index = 1
            node.elements.each do |e|
                if e.is_a? WordNode
                    firstWord = e.text_value if firstWord.nil?
                    self.writeWord(e, node)
                elsif e.is_a? KeywordNode
                    keyword = e.text_value
                end
                @db.execute("update Nodes set sort = ? where oid = ?", index, e.oid) unless e.oid.nil?
                index = index + 1
            end
            if keyword.nil? and node.elements.size > 1
                puts "Warning: link without keyword with an extension larger than one word."
            end
            keyword = firstWord if keyword.nil?

            name = self.actionNameForCurrentContext(keyword)
            @db.execute("insert into Actions (name) values (?)", name)
            idAction = @db.last_insert_row_id
            @db.execute("update Nodes set idRef = ? where oid = ?", idAction, node.oid)
        end

        def writeIfTag(node, parent)
            query = "insert into Nodes (idParent, type) values (?, ?)"
            @db.execute(query, parent.oid, TYPE_IFTAG)
            node.oid = @db.last_insert_row_id
            index = 1
            node.elements.each do |e|
                if e.is_a? JSExprNode
                    self.writeJSExpr(e, node)
                elsif e.is_a? ContentNode
                    self.writeContent(e, node)
                end
                @db.execute("update Nodes set sort = ? where oid = ?", index, e.oid) unless e.oid.nil?
                index = index + 1
            end
        end

        def writeJSExpr(node, parent)
            jscode = Uglifier.compile(node.text_value, :mangle => false)
            @db.execute("insert into JSExpr (jscode) values (?)", jscode)
            idJSExpr = @db.last_insert_row_id

            query = "insert into Nodes (idParent, type, idRef) values (?, ?, ?)"
            @db.execute(query, parent.oid, TYPE_JSEXPR, idJSExpr)
            node.oid = @db.last_insert_row_id
        end

        def writeWord(node, parent)
            text = node.text_value
            text = "NL" if node.is_a? NewLineNode
            text = "NP" if node.is_a? EndParagraphNode

            idWord, frequency = @db.get_first_row("select rowid, frequency from Words where word = ?", text)
            if frequency.nil? then
                @db.execute("insert into Words (word, frequency) values (?, 1)", text)
                idWord = @db.last_insert_row_id
            else
                frequency = frequency + 1
                @db.execute("update Words set frequency = ? where oid = ?", frequency, idWord)
            end

            query = "insert into Nodes (idParent, type, idRef) values (?, ?, ?)"
            @db.execute(query, parent.oid, TYPE_WORD, idWord)
            node.oid = @db.last_insert_row_id
        end

        def actionNameForCurrentContext(actionKeyword)
            name = nil
            if @currentPassage
                name = "p#{@currentPassage.oid}_#{actionKeyword}"
            elsif @currentItem
                name = "i#{@currentItem.oid}_#{actionKeyword}"
            end
            return name
        end


        def createTables
            # Create a database
            @db.execute("create table Words    ( word text, frequency integer )")
            @db.execute("create table JSExpr   ( jscode text )")
            @db.execute("create table Actions  ( name text, jscode text )")

            @db.execute("create table Nodes    ( idParent integer, type integer, idRef integer, sort integer )")
            @db.execute("create table Passages ( idScene integer,  name text, state text, summary text, idNode integer, jscode text )")
            @db.execute("create table Scenes   ( idModule integer, name text, summary text, jscode text )")
            @db.execute("create table Items    ( idModule integer, name text, state text, summary text, idNode integer, jscode text )")
            @db.execute("create table Modules  ( name text, summary text, jscode text )")
        end

    end

end
