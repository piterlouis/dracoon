
require 'treetop'

module DracoonGrammar

    class Treetop::Runtime::SyntaxNode
    public
        attr_accessor :oid

        def cutdown
            if self.elements.nil? then return end
            self.elements.each do |e| e.cutdown end
            if (self.respond_to? :customCutdown)
                nodes = Array.new
                self.elements.each do |e| self.customCutdown(e, nodes) end
                self.elements.clear
                self.elements.concat nodes
            end
        end
    end


    class ModuleNode < Treetop::Runtime::SyntaxNode
    public
        def customCutdown(node, children)
            if node.is_a? HeaderNode or node.is_a? SceneNode or node.is_a? ItemNode
                children << node
            elsif node.nonterminal?
                node.elements.each do |e| self.customCutdown(e, children) end
            end
        end
    end

    class HeaderNode < Treetop::Runtime::SyntaxNode
    public
        def customCutdown(node, children)
            if node.is_a? IdentifierNode or node.is_a? StateNode or node.is_a? SummaryNode or node.is_a? ScriptNode
                children << node
            elsif node.nonterminal?
                node.elements.each do |e| self.customCutdown(e, children) end
            end
        end
    end

    class SceneNode < Treetop::Runtime::SyntaxNode
    public
        def customCutdown(node, children)
            if node.is_a? HeaderNode or node.is_a? PassageNode or node.is_a? ScriptNode
                children << node
            elsif node.nonterminal?
                node.elements.each do |e| self.customCutdown(e, children) end
            end
        end
    end

    class PassageNode < Treetop::Runtime::SyntaxNode
    public
        def customCutdown(node, children)
            if node.is_a? ContentNode or node.is_a? HeaderNode or node.is_a? ActionNode then
                children << node
            elsif node.nonterminal?
                node.elements.each do |e| self.customCutdown(e, children) end
            end
        end
    end

    class ItemNode < Treetop::Runtime::SyntaxNode
    public
        def customCutdown(node, children)
            if node.is_a? ContentNode or node.is_a? HeaderNode or node.is_a? ActionNode then
                children << node
            elsif node.nonterminal?
                node.elements.each do |e| self.customCutdown(e, children) end
            end
        end
    end

    class SummaryNode < Treetop::Runtime::SyntaxNode
    public
        def cutdown
            self.elements.clear if not self.elements.nil?
        end
    end

    class EndParagraphNode < Treetop::Runtime::SyntaxNode
    public
        def cutdown
            self.elements.clear if not self.elements.nil?
        end
    end

    class ContentNode < Treetop::Runtime::SyntaxNode
    public
        def customCutdown(node, children)
            if node.is_a? WordNode or node.is_a? PunctuationNode or node.is_a? EndParagraphNode or node.is_a? NewLineNode or node.is_a? LinkNode or node.is_a? InlineTagNode or node.is_a? IfTagNode or node.is_a? ScriptTagNode then
                children << node
            elsif node.nonterminal?
                node.elements.each do |e| self.customCutdown(e, children) end
            end
        end
    end

    class ActionNode < Treetop::Runtime::SyntaxNode
    public
        def customCutdown(node, children)
            if node.is_a? KeywordNode or node.is_a? ScriptNode then
                children << node
            elsif node.nonterminal?
                node.elements.each do |e| self.customCutdown(e, children) end
            end
        end
    end

    class NewLineNode < Treetop::Runtime::SyntaxNode
    public
        def cutdown
            self.elements.clear if not self.elements.nil?
        end
    end

    class LinkNode < Treetop::Runtime::SyntaxNode
    public
        def customCutdown(node, children)
            if node.is_a? WordNode or node.is_a? KeywordNode then
                children << node
            elsif node.nonterminal?
                node.elements.each do |e| self.customCutdown(e, children) end
            end
        end
    end

    class IdentifierNode < Treetop::Runtime::SyntaxNode
    public
        def cutdown
            self.elements.clear unless self.elements.nil?
        end
    end

    class StateNode < Treetop::Runtime::SyntaxNode
    public
        def cutdown
            self.elements.clear unless self.elements.nil?
        end
    end

    class StringNode < Treetop::Runtime::SyntaxNode
    public
        def cutdown
            self.elements.clear if not self.elements.nil?
        end
    end

    class BooleanNode < Treetop::Runtime::SyntaxNode
    end

    class NilNode < Treetop::Runtime::SyntaxNode
    end

    class KeywordNode < Treetop::Runtime::SyntaxNode
    public
        def cutdown
            self.elements.clear if not self.elements.nil?
        end
    end

    class WordNode < Treetop::Runtime::SyntaxNode
    public
        def cutdown
            self.elements.clear unless self.elements.nil?
        end
    end

    class NumberNode < Treetop::Runtime::SyntaxNode
    public
        def cutdown
            self.elements.clear unless self.elements.nil?
        end
    end

    class PunctuationNode < Treetop::Runtime::SyntaxNode
    public
        def cutdown
            self.elements.clear if not self.elements.nil?
        end
    end


    class ScriptNode < Treetop::Runtime::SyntaxNode
    public
        def cutdown
            self.elements.clear if not self.elements.nil?
        end
    end

    class InlineTagNode < Treetop::Runtime::SyntaxNode
    public
        def cutdown
            body = nil
            self.elements.each do |e|
                if e.is_a? ScriptNode then
                    body = e
                    break
                end
            end
            self.elements.clear unless self.elements.nil?
            if not body.nil? then
                body.cutdown
                self.elements << body
            end
        end
    end

    class IfTagNode < Treetop::Runtime::SyntaxNode
    public
        def customCutdown(node, children)
            if node.is_a? JSExprNode or node.is_a? ContentNode then
                children << node
            elsif node.nonterminal?
                node.elements.each do |e| self.customCutdown(e, children) end
            end
        end
    end

    class ScriptTagNode < Treetop::Runtime::SyntaxNode
    end

    class JSExprNode < Treetop::Runtime::SyntaxNode
    public
        def cutdown
            self.elements.clear if not self.elements.nil?
        end
    end

end
