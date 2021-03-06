# view.rb
# generic definition of a view

require 'sdsl/module.rb'
require 'sdsl/options.rb'

View = Struct.new(:name, :modules, :trusted, :data, :critical,
                  :global, :assumptions, :protected, :ctx,
                  :appendix)

# HACK!
RET_VAR_SUFFIX = "__ret"

class View
  
  # return the first module with the name s
  def findMod s
    (modules.select { |m| m.name == s })[0]
  end
 
  # return the first datatype in this view with the name s
  def findData s
    (data.select { |d| d.name == s})[0]
  end

  # true iff this view contains at least one module that has a dynamic field
  def isDynamic
    modules.each do |m|
      if not m.dynamics.empty? then true end
    end
    false
  end

  # compute the minimum necessary scopes for commands based on
  # the numbers of datatypes, operations, and modules
  def calcScopes
    scopes = {}
    scopes[SYM_BASE_DATATYPE] = data.size - (Options.isOptOn(:OPT_GLOBAL_DATA) ? global.size : 0)
    scopes[:Op] = 0
    scopes[:Module] = 0
    modules.each do |m|
      if not m.isAbstract then scopes[:Module] += 1 end
      m.exports.each do |e|
        if not e.isAbstract then scopes[:Op] += 1 end
      end
    end
    return scopes
  end

  def to_alloy
    # type: opname -> list(modules)
    invokers = {}
    # type: opname -> list(modules)
    exporters = {}
    # type: dataname -> list(modules)
    creators = {}
    decls = {}  # declarations
    sigfacts = {} # signature facts 
    abstractOps = [] # parent operations
    fields = {}     

    # for pretty printing purposes only
    ctx[:nesting] = 0

    alloyChunk = ""
   
    modules.each do |m|
      modn = m.name.to_s
      alloyChunk += wrap(m.to_alloy(ctx))
      # invocations
      m.invokes.each do |o|
        n = o.name.to_s

        if not invokers.has_key? n then invokers[n] = [] end
        invokers[n] << modn
      end

      # exports
      m.exports.each do |o|
        n = o.name.to_s
        
        if o.parent
          p = o.parent.name.to_s
          if o.parent.isAbstract 
            abstractOps << p
          end       
          decls[n] = p
        else
          decls[n] = "Op"
        end

        if not exporters.has_key? n then exporters[n] = [] end
        exporters[n] << modn
        # op arguments
        fields[n] = []
        sigfacts[n] = []
        args = []
        ret = nil
        o.constraints[:args].each do |arg|
          if not arg.is_a? Rel
            arg = Item.new(arg, SYM_BASE_DATATYPE)
          end
          if arg.name.end_with? RET_VAR_SUFFIX
            ret = arg.to_s
          else
            args << arg.to_s
          end          
          fields[n] << arg
        end
        
        if o.parent 
          o.parent.constraints[:args].each do |arg|
            if arg.name.end_with? RET_VAR_SUFFIX
              if ret then 
                # multiple return values
                sigfacts[n] << "#{arg.to_s} in ret"
              else 
                ret = arg.to_s
              end
            else
              args << arg.to_s
            end
          end
        end
                
        if not args.empty? and not o.isAbstract     
          if not o.child
            sigfacts[n] << "args in " + args.join(" + ")
          else
            childSet = o.child.map {|e| e.name}.join(" + ")
            sigfacts[n] << 
              "this not in (#{childSet}) implies " +
              "args in " + args.join(" + ")
          end
        elsif args.empty?
          sigfacts[n] << "no args"
        end
        if ret 
          sigfacts[n] << "ret in " + ret
        else
          sigfacts[n] << "no ret"
        end        
      end

      # data creations
      m.creates.each do |d|
        if not creators.has_key? d then creators[d] = [] end
        creators[d] << modn
        # superdata = findData(d).extends
        # if not superdata == :Data
        #   if not creators.has_key? superdata then creators[superdata] = [] end
        #   creators[superdata] << modn
        # end
      end
    end

    # write facts about trusted modules
    if not trusted.empty?
      alloyChunk += writeFacts("trustedModuleFacts", 
                               ["TrustedModule = " + 
                                trusted.map { |m| m.name }.
                                join(" + ")])
    end

    if not protected.empty?
      alloyChunk += writeFacts("protectedModuleFacts", 
                               ["ProtectedModule = " + 
                                protected.map { |m| m.name }.
                                join(" + ")])
    end

    # write facts about invocation
    invokers.each do |k, v|
      if sigfacts.has_key? k
        sigfacts[k] << "sender in " + v.join(" + ")
      end
    end

    # write facts about exports
    exporters.each do |k, v|
      if sigfacts.has_key? k
        sigfacts[k] << "receiver in " + v.join(" + ")
      end
    end

    # write op declarations
    decls.each do |k, v|
      alloyChunk += writeComment("operation #{k}")     
      if abstractOps.include? k
         alloyChunk += "abstract "
      end
      alloyChunk += wrap("sig " + k + " extends " + v + " {")
      # fields      
      fields[k].each do |f|
        alloyChunk += wrap(f.to_alloy(ctx) + ",", 1)
      end
      alloyChunk += "}"
      # signature facts
      if sigfacts.has_key? k
        alloyChunk += wrap("{")
        sigfacts[k].each do |f|
          alloyChunk += wrap(f, 1)
        end
        alloyChunk += wrap("}")
      end
    end

    # write facts about data creation
    # dataFacts = []
    # data.each do |d|
    #   dn = d.name

    #   if creators.has_key? dn
    #     dataFacts << "creates.#{dn} in " + creators[dn].join(" + ")
    #   else 
    #     if critical.any? { |c| c.name == dn }
    #       dataFacts << "no creates.#{dn}"
    #     end
    #   end 
    # end

    # alloyChunk += writeFacts("dataFacts", dataFacts)
    
    # write data decls
    alloyChunk += writeComment("datatype declarations") 
    extendsMap = {}
    data.each do |d|
      if d.extends and "#{d.extends}" != "Data" then 
        extendsMap[d] = findData(d.extends)
      end      
    end
    ctx[:extendsMap] = extendsMap
    data.each do |d|     
      alloyChunk += d.to_alloy(ctx,Options.isOptOn(:OPT_GLOBAL_DATA) && (global.include? d))
    end
    alloyChunk += wrap("sig OtherData extends Data {}")
    
    # write critical data fact
    if not critical.empty?
      alloyChunk += writeFacts("criticalDataFacts", 
                               ["CriticalData = " + 
                                critical.map { |d| d.name.to_s }.
                                join(" + ")])
    end

    # write assumptions
    if not assumptions.empty?
      alloyChunk += writeFacts("assumptions", 
                               assumptions.map { |a| a.to_alloy(ctx)})
    end
      
    # append any other extra Alloy expressions
    appendix.each do |a|
      alloyChunk += a
    end
   
    alloyChunk
  end

  def appendFun f
    appendix << f
  end
  # View
end

class ViewBuilder 
  def initialize 
    @modules = []
    @trusted = []
    @data = []
    @critical = []
    @global = []
    @assumptions = []
    @protected = []
    @ctx = {}
    @appendix = []
  end
  
  def data(*data)
    @data += data.map{ |d| 
      if d.is_a? Datatype
        d
      else 
        Datatype.new(d, [], SYM_BASE_DATATYPE, false, []) 
      end
    }
  end

  def critical(*data)
    @critical += data.map { |d| 
      if d.is_a? Datatype
        d
      else
        Datatype.new(d, [], SYM_BASE_DATATYPE, false, [])
      end
    }
  end

  def global(*data)
    @global += data.map { |d| 
      if d.is_a? Datatype
        d
      else
        Datatype.new(d, [], SYM_BASE_DATATYPE, false, [])
      end
    }
  end

  def modules(*mods)
    @modules += mods
  end

  def trusted(*mods)
    @trusted += mods
  end

  def assumes(*assums)
    @assumptions += assums
  end

  def protected(*mods)
    @protected += mods
  end

  def checkWellformedness
    allExports = @modules.inject([]) {|r, m| r + m.exports}
    allExports.each do |e|
      if (@modules.select { |m| m.findExport e.name }).count > 1
        raise "#{e.name} is exported by multiple modules!"
      end
    end
  end

  def build name
    checkWellformedness
    View.new(name, @modules, @trusted,
             @data, @critical, @global, 
             @assumptions, @protected, @ctx, @appendix)
  end
end

def view(name, &block)
  Docile.dsl_eval(ViewBuilder.new, &block).build name
end

def mapping(name, &block)
  Docile.dsl_eval(MappingBuilder.new, &block).build name
end

# precond: both sup and sub are symbols
def mkMixedName(sup, sub) 
  (sup.to_s + "_" + sub.to_s).to_sym
end

def refineExports(sup, sub, exportsRel) 
  exports = []
  subExports = sub.exports.dup
  sup.exports.each do |o|
    n = o.name
    if exportsRel.has_key? n 
      matches = sub.exports.select { |o2| o2.name == exportsRel[n] }      
      if not matches.empty?
        o2 = matches[0]
        exports << Op.new(n, 
                          {:when => (o.constraints[:when]),
                            :args => (o.constraints[:args])}, o2, 
                          nil, false, o.modifies, o.types)
        # if exportsRel has both o1 -> o2 and o2 -> o1 as mapping,
        # set o2 abstract s.t. instances(o1) = instances(o2)
        if exportsRel.has_key? o2.name
          o2.isAbstract = true
        end
# TODO: Is this right? Too weak?       
#        subExports.delete(o2)
        next
      end
    end
    exports << o
  end  
  exports
end

def refineInvokes(sup, sub, invokesRel)
  invokes = []
  subInvokes = sub.invokes.dup
  sup.invokes.each do |o|
    n = o.name

    if invokesRel.has_key? n 
      matches = sub.invokes.select { |o2| o2.name == invokesRel[n] }    

      if not matches.empty?
        o2 = matches[0]    
        invokes << Op.new(n, 
                          {:when => (o.constraints[:when])},
                          o2, nil, false, o.modifies, o.types)  
# TODO: Is this right? Too weak?        
#        subInvokes.delete(o2)
        next
      end
    end
    invokes << o
  end  
  invokes
end

def abstractExports(m1, m2, exportsRel)
  exports = []
  m2Exports = m2.exports.dup
  m1.exports.each do |o|
    n = o.name

    if exportsRel.has_key? n 
      matches = m2.exports.select { |o2| o2.name == exportsRel[n] }      
      if not matches.empty?
        o2 = matches[0]   
        exports << Op.new(n, #mkMixedName(n, o2.name), 
                          {:when => union(o.constraints[:when],
                                          o2.constraints[:when]),
                            :args => myuniq(o.constraints[:args] + 
                                            o2.constraints[:args])}, 
                          nil, nil,
                          false, 
                          safeUnion(o.modifies,o2.modifies),
                          safeUnion(o.types, o2.types))
        m2Exports.delete(o2)
        next
      end
    end

    exports << o
  end  
  exports + m2Exports  
end

def abstractInvokes(m1, m2, invokesRel)
  invokes = []
  m2Invokes = m2.invokes.dup

  m1.invokes.each do |o|
    n = o.name
    
    if invokesRel.has_key? n 
      matches = m2.invokes.select { |o2| o2.name == invokesRel[n] } 

      if not matches.empty?
        o2 = matches[0]     
        invokes << Op.new(n, #mkMixedName(n, o2.name),
                          {:when => union(o.constraints[:when],
                                          o2.constraints[:when])},
                          nil, nil,
                          false, 
                          safeUnion(o.modifies, o2.modifies),
                          safeUnion(o.types, o2.types))
        m2Invokes.delete(o2)
        next
      end
    end

    invokes << o
  end

  invokes + m2Invokes
end

# sup is the module being refined
# sub is the module refining
# sup is a supertype of sub
def refineMod(sup, sub, exportsRel, invokesRel)
  if sup.name == sub.name
    name = ("#{sup.name}_").to_sym
  else 
    name = sup.name
  end
  # refinement
  exports = refineExports(sup, sub, exportsRel)  
  invokes = refineInvokes(sup, sub, invokesRel)
  assumptions = sub.assumptions
  stores = sup.stores
  creates = sup.creates
  extends = [sub]
  isAbstract = false
  isUniq = sup.isUniq  #TODO: Fix it later
  dynamics = sup.dynamics

  Mod.new(name, exports, invokes, assumptions, stores, creates, 
          extends, isAbstract, isUniq, dynamics, [sup])
end

def mergeMod(m1, m2, exportsRel, invokesRel)
  name = m1.name #mkMixedName(m1.name, m2.name)
  # abstraction
  exports = abstractExports(m1, m2, exportsRel)  
  invokes = abstractInvokes(m1, m2, invokesRel)
  assumptions = m2.assumptions + m1.assumptions
  stores = myuniq(m2.stores + m1.stores)
  creates = m2.creates + m1.creates
# extends = m1
  isAbstract = false
  isUniq = m1.isUniq #TODO: Fix it later
  dynamics = myuniq(m2.dynamics + m1.dynamics)
  types = myuiq(m2.types + m1.types)

  Mod.new(name, exports, invokes, assumptions, stores, creates, 
          [], isAbstract, isUniq, dynamics, types)
end

def mergeParts(v1, v2, refineRel)
  dataMap = {}
  opMap = {}
  moduleMap = {}
  
  exportsRel = refineRel[:Exports]
  invokesRel = refineRel[:Invokes]

  dataRel = refineRel[:Data]
  dataRel.each do |from, to|
    sub = v1.findData(from)
    sup = v2.findData(to)    
#    dataMap[from] = Datatype.new(sub.name, sub.fields, sup.name, false)
#    dataMap[to] = Datatype.new(sup.name, sup.fields, SYM_BASE_DATATYPE, true)
    dataMap[from] = Datatype.new(sub.name, sub.fields, sup.name, 
                                 sub.isAbstract, sub.isSingleton,
                                 (sub.types << sup.name))
    if sup.isSingleton then
      raise "The datatype named #{to} being extended can't be singleton!"
    end
    dataMap[to] = Datatype.new(sup.name, sup.fields, sup.extends, 
                               sup.isAbstract, sup.isSingleton,
                               sup.types)
  end

  v1.data.each do |d1| 
    v2.data.each do |d2|
      if d1.name == d2.name
        extends = SYM_BASE_DATATYPE
        if not (d1.extends == SYM_BASE_DATATYPE or d2.extends == SYM_BASE_DATATYPE) and
            not (d1.extends == d2.extends) then
          raise "Conflicting data types: Same name with different supertype"
        else
          if not d1.extends == SYM_BASE_DATATYPE then 
            extends = d1.extends 
          else
            extends = d2.extends
          end
        end

        if d1.extends != SYM_BASE_DATATYPE then extends = d1.extends end
        if d2.extends != SYM_BASE_DATATYPE then extends = d2.extends end
        newData = Datatype.new(d1.name, myuniq(d1.fields + d2.fields),
                               extends, false, myuniq(d1.types + d2.types))   
        dataMap[d1.name] = newData
        dataMap[d2.name] = newData
      end
    end
  end

  modRel = refineRel[:Module]
  modRel.each do |from, to|
    sup = v1.findMod(from)    
    sub = v2.findMod(to)
    if sup.name == sub.name
      # merging; horizontal composition
      sub2 = sub.deepclone
      newMod = mergeMod(sup, sub, exportsRel, invokesRel)
      moduleMap[sup] = newMod
      moduleMap[sub] = newMod
    else
      # refinement; vertical composition
      sub2 = sub.deepclone
      newMod = refineMod(sup, sub2, exportsRel, invokesRel)
      moduleMap[sup] = newMod
      moduleMap[sub] = sub2 #TODO: too strong, fix later
      moduleMap[sub].setAbstract
      moduleMap[sub].isUniq = false      
    end
  end

  dataMap.update(opMap).update(moduleMap)
end

# returns three maps that represent refinement relations
# 1. map from each datatype in (v1 + v2) to a dataype 
# 2. map from each operation in (v1 + v2) to an operation
# 3. map from each module in (v1 + v2) to a module
def buildView(v1, v2, mapping, refineRel)
  modRel = refineRel[:Module]
  exportsRel = refineRel[:Exports]
  invokesRel = refineRel[:Invokes]
  modules = []
  ctx = {}
  opRel = {}

  (v1.modules + v2.modules).each do |m| 
    if not ctx.has_key? m.name then ctx[m.name] = Set.new([]) end

    if mapping.has_key? m 
      modules << mapping[m]
      ctx[m.name].add(mapping[m].name)
    else
      modules << m.deepclone
      ctx[m.name].add(m.name)
    end
  end
  modules = myuniq(modules)
  
  # TODO: Probably need this
  # invokesRel.each do |from, to|
  #   if from == to then next end
  #   o = mkMixedName(from, to)
  #   if modules.any? { |m| m.findExport(o) } then next end

  #   o1 = v1.findModsWithExport(from)[0].findExport(from)  

  #   modules.each do |m| 
  #     if m.findExport o or not (m.findExport to) then next end
  #     o2 = m.findExport to     
  #     m.exports << Op.new(from,
  #                         {:when => [],
  #                           :args => (o1.constraints[:args])}, o2, o1)
  #     # simplification
  #     # if m1.invokes op1, op2 in m2 and op1 is a specialization of op2, 
  #     # then remove op2 from m1.invokes
  #     modules.select { |m2| m2.findInvoke o and m2.findInvoke to}.each do |m2|
  #       m2.invokes.delete(m2.findInvoke to)
  #     end 
  #   end
  # end

  # trusted modules
  trusted = (v1.trusted + v2.trusted).map{ |m| if mapping.has_key? m then 
                                                 mapping[m] 
                                               else 
                                                 m end}
  # data
  data = (v1.data + v2.data).map { |d| if mapping.has_key? d.name then 
                                         mapping[d.name]
                                       else 
                                         d
                                       end}
  otherData = []
  data.each do |d|
    dn = d.name
    i = data.find_index { |d2| d2.extends == dn }
    if i then
      otherData << Datatype.new(("Other#{dn}").to_sym, [], dn, false, []) 
    end
  end
  data += otherData
  data = myuniq(data)

  # assumptions
  assumptions = (v1.assumptions + v2.assumptions)
    
  modules.each do |m| 
    # establish subtyping relationships between operations
    (m.exports + m.invokes).each do |o|
      if o.parent then 
        if not o.parent.child then o.parent.child = [] end
        o.parent.child << o
      end
    end
    
    # m.invokes.each do |o1|
    #   if m.extends[0]        
    #     # m2 is a parent of m
    #     m2 = m.extends[0]
        
    #     m2.invokes.each do |o2|  
    #       # find the module that exports o1
    #       emod1 = (findModsWithExport(modules, o1.name))[0]
    #       eop1 = emod1.findExport o1.name
          
    #       if eop1.parent && eop1.parent.name == o2.name
    #         if eop1.parent.isAbstract
    #           next
    #         end

    #         if o1.parent && o1.parent.name == eop1.parent.name
    #           next
    #         end

    #         if o1.constraints[:when].empty? or o2.constraints[:when].empty?
    #           newConstraints = []
    #         else               
    #           newConstraints =  union(o1.constraints[:when], 
    #                                   o2.constraints[:when])
    #         end
    #         o1.constraints = 
    #           {:args => o1.constraints[:args],
    #           :when => newConstraints}
    #       end
    #     end
    #   end
    # end

  end

  View.new(:MergedView, modules, trusted,
           data, v1.critical, v1.global + v2.global, 
           assumptions, v1.protected, ctx, v1.appendix + v2.appendix)
end

def findModsWithExport(modules, n)
  (modules.select { |m| m.exports.any? { |e| e.name == n }})
end

def inferMapping(v1, v2, refineRel) 
  if not refineRel.has_key? :Module then refineRel[:Module] = {} end
  if not refineRel.has_key? :Exports then refineRel[:Exports] = {} end
  if not refineRel.has_key? :Invokes then refineRel[:Invokes] = {} end
  if not refineRel.has_key? :Data then refineRel[:Data] = {} end

  newRel = refineRel.clone
  v1.modules.each do |m1|
    v2.modules.each do |m2|
      if m1.name == m2.name then
        newRel[:Module][m1.name] = m2.name
        # check exports
        m1.exports.each do |e1|
          m2.exports.each do |e2|
            if e1.name == e2.name then
              newRel[:Exports][e1.name] = e2.name
            end
          end
        end

        # check invokes
        m1.invokes.each do |i1|
          m2.invokes.each do |i2|
            if i1.name == i2.name then
              newRel[:Invokes][i1.name] = i2.name
            end
          end
        end
      end
    end
  end
  return newRel
end

def composeViews(v1, v2, refineRel = {})
  puts "*** Attempting to merge #{v1.name} and #{v2.name} ***:"
  # Given refinement relations, derive a mapping between elements of two views
  refineRel = inferMapping(v1, v2, refineRel)
  mapping = mergeParts(v1, v2, refineRel)

#  pp "*** Intermediate Mapping:"
#  pp mapping

  # Construct a new view based on the relations between the two views
  mergeResult = buildView(v1, v2, mapping, refineRel)

  puts "*** Successfully merge #{v1.name} and #{v2.name} ***:"
  puts ""
#  pp mergeResult
  mergeResult
end
