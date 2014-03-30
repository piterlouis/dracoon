
require 'sqlite3'
require 'uglifier'

load 'dracoon_nodes.rb'


module Dracoon

    class SQLiteWriter
        include DracoonGrammar

        TYPE_ROOT         =  1
        TYPE_MODULE       =  2
        TYPE_SCENE        =  3
        TYPE_PASSAGE      =  4
        TYPE_ITEM         =  5
        TYPE_HEADER       =  6
        TYPE_STATE        =  7
        TYPE_SUMMARY      =  8
        TYPE_CONTENT      =  9
        TYPE_ACTION       = 10
        TYPE_NEWLINE      = 11
        TYPE_ENDPARAGRAPH = 12
        TYPE_LINK         = 13
        TYPE_IDENTIFIER   = 14
        TYPE_STRING       = 15
        TYPE_KEYWORD      = 16
        TYPE_WORD         = 17
        TYPE_NUMBER       = 18
        TYPE_PUNCTUATION  = 19
        TYPE_SCRIPT       = 20
        TYPE_JSEXPR       = 21
        TYPE_INLINETAG    = 22
        TYPE_IFTAG        = 23
        TYPE_SCRIPTTAG    = 24


        @db = nil
        @currentModule  = nil
        @currentItem    = nil
        @currentScene   = nil
        @currentPassage = nil


        def initialize
            File::delete('gamebook.db') if File::exist? 'gamebook.db'
            @db = SQLite3::Database.new('gamebook.db')
            self.createTables
        end

        def writeAST(node, parent)
            type = nil
            content = node.text_value
            if    node.is_a? ModuleNode       then self.writeModule(node, parent)
            elsif node.is_a? ItemNode         then self.writeItem(node, parent)
            elsif node.is_a? SceneNode        then self.writeScene(node, parent)
            elsif node.is_a? PassageNode      then self.writePassage(node, parent)
            elsif node.is_a? HeaderNode       then self.writeNode(node, parent, TYPE_HEADER)
            elsif node.is_a? SummaryNode      then self.writeNode(node, parent, TYPE_SUMMARY, content)
            elsif node.is_a? EndParagraphNode then self.writeNode(node, parent, TYPE_ENDPARAGRAPH)
            elsif node.is_a? ContentNode      then self.writeNode(node, parent, TYPE_CONTENT)
            elsif node.is_a? ActionNode       then self.writeNode(node, parent, TYPE_ACTION)
            elsif node.is_a? NewLineNode      then self.writeNode(node, parent, TYPE_NEWLINE)
            elsif node.is_a? LinkNode         then self.writeNode(node, parent, TYPE_LINK)
            elsif node.is_a? IdentifierNode   then self.writeNode(node, parent, TYPE_IDENTIFIER, content)
            elsif node.is_a? StateNode        then self.writeNode(node, parent, TYPE_STATE, content)
            elsif node.is_a? StringNode       then self.writeNode(node, parent, TYPE_STRING, content)
            elsif node.is_a? KeywordNode      then self.writeNode(node, parent, TYPE_KEYWORD, content)
            elsif node.is_a? WordNode         then self.writeNode(node, parent, TYPE_WORD, content)
            elsif node.is_a? NumberNode       then self.writeNode(node, parent, TYPE_NUMBER, content)
            elsif node.is_a? PunctuationNode  then self.writeNode(node, parent, TYPE_PUNCTUATION, content)
            elsif node.is_a? ScriptNode       then self.writeScript(node, parent)
            elsif node.is_a? InlineTagNode    then self.writeNode(node, parent, TYPE_INLINETAG)
            elsif node.is_a? IfTagNode        then self.writeNode(node, parent, TYPE_IFTAG)
            elsif node.is_a? ScriptTagNode    then self.writeNode(node, parent, TYPE_SCRIPTTAG)
            elsif node.is_a? JSExprNode       then self.writeNode(node, parent, TYPE_JSEXPR, content)
            end

            node.elements.each { |e|
                self.writeAST(e, node)
            } unless node.elements.nil?

            # Updating all modules to point to root node
            @db.execute("update Nodes set idParent = 1 where type = ? and idParent is NULL", TYPE_MODULE)
        end

        def writeNode(node, parent, type, content=nil)
            if parent.nil?
                if content.nil?
                    @db.execute("insert into Nodes (type) values (?)", type)
                else
                    @db.execute("insert into Nodes (type, content) values (?, ?)", type, content)
                end
            else
                if content.nil?
                    @db.execute("insert into Nodes (idParent, type) values (?, ?)", parent.oid, type)
                else
                    @db.execute("insert into Nodes (idParent, type, content) values (?, ?, ?)", parent.oid, type, content)
                end
            end
            node.oid = @db.last_insert_row_id
        end

        def writeModule(node, parent)
            moduleName = self.getHeaderNameOfNode(node)
            idNode = @db.get_first_row("select idNode from Modules where name = ?", moduleName)
            if idNode.nil?
                self.writeNode(node, parent, TYPE_MODULE)
                node.oid = @db.last_insert_row_id
                @db.execute("insert into Modules (idNode, name) values (?, ?)", node.oid, moduleName)
            else
                removeHeaderOfNode(node)
                node.oid = idNode
            end

            @currentModule = node
            @currentItem = nil
            @currentScene = nil
            @currentPassage = nil
        end

        def writeItem(node, parent)
            itemName = self.getHeaderNameOfNode(node)
            idNode = @db.get_first_row("select idNode from Items where idModule = ? and name = ?", @currentModule.oid, itemName)
            if idNode.nil?
                self.writeNode(node, parent, TYPE_ITEM)
                node.oid = @db.last_insert_row_id
                @db.execute("insert into Items (idNode, idModule, name) values (?, ?, ?)", node.oid, @currentModule.oid, itemName)
            else
                removeHeaderOfNode(node)
                node.oid = idNode
            end

            @currentItem = node
            @currentScene = nil
            @currentPassage = nil
        end

        def writeScene(node, parent)
            sceneName = self.getHeaderNameOfNode(node)
            idNode = @db.get_first_row("select idNode from Scenes where idModule = ? and name = ?", @currentModule.oid, sceneName)
            if idNode.nil?
                self.writeNode(node, parent, TYPE_SCENE)
                node.oid = @db.last_insert_row_id
                @db.execute("insert into Scenes (idNode, idModule, name) values (?, ?, ?)", node.oid, @currentModule.oid, sceneName)
            else
                removeHeaderOfNode(node)
                node.oid = idNode
            end

            @currentScene = node
            @currentPassage = nil
            @currentItem = nil
        end

        def writePassage(node, parent)
            passageName = self.getHeaderNameOfNode(node)
            idNode = @db.get_first_row("select idNode from Passages where idScene = ? and name = ?", @currentScene.oid, passageName)
            if idNode.nil?
                self.writeNode(node, parent, TYPE_PASSAGE)
                node.oid = @db.last_insert_row_id
                @db.execute("insert into Passages (idNode, idScene, name) values (?, ?, ?)", node.oid, @currentScene.oid, passageName)
            else
                removeHeaderOfNode(node)
                node.oid = idNode
            end

            @currentPassage = node
        end

        def writeScript(node, parent)
            jscode = node.text_value
            self.writeNode(node, parent, TYPE_SCRIPT)
            jscode = "var o#{node.oid} = {#{jscode}} ;"
            jscode = Uglifier.compile(jscode, :mangle => false)
            @db.execute("update Nodes set content = ? where oid = ?", jscode, node.oid)
        end


        def getHeaderNameOfNode(node)
            name = nil
            node.elements.each do |e|
                if e.is_a? HeaderNode
                    e.elements.each do |he|
                        if he.is_a? IdentifierNode
                            name = he.text_value
                            break;
                        end
                    end
                    break;
                end
            end
            return name;
        end

        def removeHeaderOfNode(node)
            header = nil
            node.elements.each do |e|
                if e.is_a? HeaderNode
                    header = e
                    break
                end
            end
            node.elements.delete(header) unless header.nil?
        end


        def createTables
            # Create a database
            @db.execute("create table Nodes    ( idParent integer, type integer, content text )")
            @db.execute("create table Passages ( idNode integer, idScene integer, name text )")
            @db.execute("create table Scenes   ( idNode integer, idModule integer, name text )")
            @db.execute("create table Items    ( idNode integer, idModule integer, name text )")
            @db.execute("create table Modules  ( idNode integer, name text )")
            # Inserting root node
            @db.execute("insert into Nodes (type) values (?)", TYPE_ROOT)
        end

    end

end
