
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

		def initialize
			File::delete('gamebook.db') if File::exist? 'gamebook.db'
			@db = SQLite3::Database.new('gamebook.db')
			self.createTables
		end

		def writeModule(node)
			@db.execute("insert into Modules (name) values ('')")
			node.oid = @db.last_insert_row_id
			node.elements.each do |e|
				if e.is_a? HeaderNode
					self.writeHeader(e, node)
				elsif e.is_a? SceneNode
					self.writeScene(e, node)
				end
			end
		end

		def writeScene(node, parent)
			@db.execute("insert into Scenes (moduleId) values (?)", parent.oid)
			node.oid = @db.last_insert_row_id
			node.elements.each do |e|
				if e.is_a? HeaderNode
					self.writeHeader(e, node)
				elsif e.is_a? PassageNode
					self.writePassage(e, node)
				elsif e.is_a? ObjectNode
					self.writeObject(e, node)
				end
			end
		end

		def writePassage(node, parent)
			@db.execute("insert into Passages (sceneId) values (?)", parent.oid)
			node.oid = @db.last_insert_row_id
			node.elements.each do |e|
				if e.is_a? HeaderNode
					self.writeHeader(e, node)
				elsif e.is_a? ContentNode
					self.writeContent(e, nil, node)
				elsif e.is_a? ActionNode
					self.writeAction(e, node)
				end
			end
		end

		def writeObject(node, parent)
			@db.execute("insert into Objects (sceneId) values (?)", parent.oid)
			node.oid = @db.last_insert_row_id
			node.elements.each do |e|
				if e.is_a? HeaderNode
					self.writeHeader(e, node)
				elsif e.is_a? ContentNode
					self.writeContent(e, nil, node)
				elsif e.is_a? ActionNode
					self.writeAction(e, node)
				end
			end
		end

		def writeHeader(node, parent)
			entityName = nil
			name = nil
			description = nil
			jscode = nil
			node.elements.each do |e|
				if e.is_a? IdentifierNode
					name = e.text_value
				elsif e.is_a? DescriptionNode
					description = e.text_value
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
			elsif parent.is_a? ObjectNode
				entityName = 'Objects'
				jscode = "var o#{parent.oid} = {#{jscode}} ;"
			end
			jscode = Uglifier.compile(jscode, :mangle => false)
			query = "update #{entityName} set name=?, description=?, jscode=? where oid=?"
			@db.execute(query, name, description, jscode, parent.oid)
		end

		def writeContent(node, parent, passage)
			@db.execute("insert into Nodes (passageId, type) values (?, ?)", passage.oid, TYPE_CONTENT)
			node.oid = @db.last_insert_row_id
			index = 1
			node.elements.each do |e|
				if e.is_a? WordNode or e.is_a? PunctuationNode or e.is_a? NewLineNode or e.is_a? EndParagraphNode
					self.writeWord(e, node, passage)
				elsif e.is_a? LinkNode
					self.writeLink(e, node, passage)
				elsif e.is_a? IfTagNode
					self.writeIfTag(e, node, passage)
				end
				@db.execute("update Nodes set sort = ? where oid = ?", index, e.oid)
				index = index + 1
			end
		end

		def writeAction(node, parent)
			keyword = nil
			jscode = nil
			node.elements.each do |e|
				if e.is_a? KeywordNode
					keyword = e.text_value
				elsif e.is_a? ScriptNode
					jscode = e.text_value
				end
			end
			begin
				jscode = "var p#{parent.oid}_#{keyword} = {#{jscode}} ;"
				jscode = Uglifier.compile(jscode, :mangle => false)
			rescue
				puts 'Error trying to uglifying code: ' + jscode
			end

			aoid = @db.get_first_row("select rowid from Actions where name = ?", keyword)
			if aoid.nil? then
				puts "Warning: Definition of action [#{keyword}] without associated link."
				@db.execute("insert into Actions (name, jscode) values (?, ?)", keyword, jscode)
				aoid = @db.last_insert_row_id
			else
				@db.execute("update Actions set jscode = ? where oid = ?", jscode, aoid)
			end
			node.oid = aoid
		end

		def writeLink(node, parent, passage)
			@db.execute("insert into Nodes (passageId, parentId, type) values (?, ?, ?)", passage.oid, parent.oid, TYPE_LINK)
			node.oid = @db.last_insert_row_id
			keyword = nil
			firstWord = nil
			index = 1
			node.elements.each do |e|
				if e.is_a? WordNode
					firstWord = e.text_value if firstWord.nil?
					self.writeWord(e, node, passage)
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

			@db.execute("insert into Actions (nodeId, name) values (?, ?)", parent.oid, keyword)
			actionId = @db.last_insert_row_id
			@db.execute("update Nodes set ref = ? where oid = ?", actionId, node.oid)
		end

		def writeIfTag(node, parent, passage)
			query = "insert into Nodes (passageId, parentId, type) values (?, ?, ?)"
			@db.execute(query, passage.oid, parent.oid, TYPE_IFTAG)
			node.oid = @db.last_insert_row_id
			index = 1
			node.elements.each do |e|
				if e.is_a? JSExprNode
					self.writeJSExpr(e, node, passage)
				elsif e.is_a? ContentNode
					self.writeContent(e, node, passage)
				end
				@db.execute("update Nodes set sort = ? where oid = ?", index, e.oid) unless e.oid.nil?
				index = index + 1
			end
		end

		def writeJSExpr(node, parent, passage)
			jscode = Uglifier.compile(node.text_value, :mangle => false)
			@db.execute("insert into Expressions (jscode) values (?)", jscode)
			jsExprId = @db.last_insert_row_id

			query = "insert into Nodes (passageId, parentId, type, ref) values (?, ?, ?, ?)"
			@db.execute(query, passage.oid, parent.oid, TYPE_JSEXPR, jsExprId)
			node.oid = @db.last_insert_row_id
		end

		def writeWord(node, parent, passage)
			text = node.text_value
			text = "NL" if node.is_a? NewLineNode
			text = "NP" if node.is_a? EndParagraphNode

			woid, frequency = @db.get_first_row("select rowid, frequency from Words where word = ?", text)
			if frequency.nil? then
				@db.execute("insert into Words (word, frequency) values (?, 1)", text)
				woid = @db.last_insert_row_id
			else
				frequency = frequency + 1
				@db.execute("update Words set frequency = ? where oid = ?", frequency, woid)
			end

			query = "insert into Nodes (passageId, parentId, type, ref) values (?, ?, ?, ?)"
			@db.execute(query, passage.oid, parent.oid, TYPE_WORD, woid)
			node.oid = @db.last_insert_row_id
		end


		def createTables
			# Create a database
			@db.execute("create table Words ( word text, frequency integer )")
			@db.execute("create table Expressions ( jscode text )")
			@db.execute("create table Actions ( nodeId integer, name text, jscode text )")

			@db.execute("create table Nodes ( passageId integer, parentId integer, type integer, ref integer, sort integer )")
			@db.execute("create table Objects ( sceneId integer, name text, state text, description text, jscode text )")
			@db.execute("create table Passages ( sceneId integer, name text, state text, description text, jscode text )")
			@db.execute("create table Scenes ( moduleId integer, name text, description text, jscode text )")
			@db.execute("create table Modules ( name text, description text, jscode text )")
		end

	end

end
