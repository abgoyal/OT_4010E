package CodeGeneratorV8;

use File::stat;
use Digest::MD5;

my $module = "";
my $outputDir = "";

my @headerContent = ();
my @implContentHeader = ();
my @implFixedHeader = ();
my @implContent = ();
my @implContentDecls = ();
my %implIncludes = ();

my @allParents = ();

# Default .h template
my $headerTemplate = << "EOF";
EOF

# Default constructor
sub new
{
    my $object = shift;
    my $reference = { };

    $codeGenerator = shift;
    $outputDir = shift;

    bless($reference, $object);
    return $reference;
}

sub finish
{
    my $object = shift;

    # Commit changes!
    $object->WriteData();
}

sub leftShift($$) {
    my ($value, $distance) = @_;
    return (($value << $distance) & 0xFFFFFFFF);
}

# Workaround for V8 bindings difference where RGBColor is not a POD type.
sub IsPodType
{
    my $type = shift;
    return $codeGenerator->IsPodType($type);
}

# Params: 'domClass' struct
sub GenerateInterface
{
    my $object = shift;
    my $dataNode = shift;
    my $defines = shift;

    # Start actual generation
    $object->GenerateHeader($dataNode);
    $object->GenerateImplementation($dataNode);

    my $name = $dataNode->name;

    # Open files for writing
    my $headerFileName = "$outputDir/V8$name.h";
    my $implFileName = "$outputDir/V8$name.cpp";

    open($IMPL, ">$implFileName") || die "Couldn't open file $implFileName";
    open($HEADER, ">$headerFileName") || die "Couldn't open file $headerFileName";
}

# Params: 'idlDocument' struct
sub GenerateModule
{
    my $object = shift;
    my $dataNode = shift;

    $module = $dataNode->module;
}

sub GetLegacyHeaderIncludes
{
    my $legacyParent = shift;

    die "Don't know what headers to include for module $module";
}

sub AvoidInclusionOfType
{
    my $type = shift;

    # Special case: SVGRect.h / SVGPoint.h / SVGNumber.h / SVGMatrix.h do not exist.
    return 1 if $type eq "SVGRect" or $type eq "SVGPoint" or $type eq "SVGNumber" or $type eq "SVGMatrix";
    return 0;
}

sub UsesManualToJSImplementation
{
    my $type = shift;

    return 1 if $type eq "SVGPathSeg";
    return 0;
}

sub AddIncludesForType
{
    my $type = $codeGenerator->StripModule(shift);

    # When we're finished with the one-file-per-class
    # reorganization, we won't need these special cases.
    if (!$codeGenerator->IsPrimitiveType($type) and !AvoidInclusionOfType($type) and $type ne "Date") {
        # default, include the same named file
        $implIncludes{GetV8HeaderName(${type})} = 1;

        if ($type =~ /SVGPathSeg/) {
            $joinedName = $type;
            $joinedName =~ s/Abs|Rel//;
            $implIncludes{"${joinedName}.h"} = 1;
        }
    }

    # additional includes (things needed to compile the bindings but not the header)

    if ($type eq "CanvasRenderingContext2D") {
        $implIncludes{"CanvasGradient.h"} = 1;
        $implIncludes{"CanvasPattern.h"} = 1;
        $implIncludes{"CanvasStyle.h"} = 1;
    }

    if ($type eq "CanvasGradient" or $type eq "XPathNSResolver") {
        $implIncludes{"PlatformString.h"} = 1;
    }

    if ($type eq "CSSStyleDeclaration") {
        $implIncludes{"CSSMutableStyleDeclaration.h"} = 1;
    }

    if ($type eq "Plugin" or $type eq "PluginArray" or $type eq "MimeTypeArray") {
        # So we can get String -> AtomicString conversion for namedItem().
        $implIncludes{"AtomicString.h"} = 1;
    }
}

sub AddIncludesForSVGAnimatedType
{
    my $type = shift;
    $type =~ s/SVGAnimated//;

    if ($type eq "Point" or $type eq "Rect") {
        $implIncludes{"Float$type.h"} = 1;
    } elsif ($type eq "String") {
        $implIncludes{"PlatformString.h"} = 1;
    }

    $implIncludes{"SVGAnimatedTemplate.h"} = 1;
}

sub AddClassForwardIfNeeded
{
    my $implClassName = shift;

    # SVGAnimatedLength/Number/etc.. are typedefs to SVGAnimtatedTemplate, so don't use class forwards for them!
    push(@headerContent, "class $implClassName;\n\n") unless $codeGenerator->IsSVGAnimatedType($implClassName);
}

# If the node has a [Conditional=XXX] attribute, returns an "ENABLE(XXX)" string for use in an #if.
sub GenerateConditionalString
{
    my $node = shift;
    my $conditional = $node->extendedAttributes->{"Conditional"};
    if ($conditional) {
        return "ENABLE(" . join(") && ENABLE(", split(/&/, $conditional)) . ")";
    } else {
        return "";
    }
}

sub GenerateHeader
{
    my $object = shift;
    my $dataNode = shift;

    my $interfaceName = $dataNode->name;
    my $className = "V8$interfaceName";
    my $implClassName = $interfaceName;

    # Copy contents of parent classes except the first parent or if it is
    # EventTarget.
    $codeGenerator->AddMethodsConstantsAndAttributesFromParentClasses($dataNode, \@allParents, 1);

    my $hasLegacyParent = $dataNode->extendedAttributes->{"LegacyParent"};
    my $conditionalString = GenerateConditionalString($dataNode);

    # - Add default header template
    @headerContent = split("\r", $headerTemplate);

    push(@headerContent, "\n#if ${conditionalString}\n\n") if $conditionalString;
    push(@headerContent, "\n#ifndef $className" . "_H");
    push(@headerContent, "\n#define $className" . "_H\n\n");

    # Get correct pass/store types respecting PODType flag
    my $podType = $dataNode->extendedAttributes->{"PODType"};

    push(@headerContent, "#include \"$podType.h\"\n") if $podType and ($podType ne "double" and $podType ne "float" and $podType ne "RGBA32");

    push(@headerContent, "#include <v8.h>\n");
    push(@headerContent, "#include <wtf/HashMap.h>\n");
    push(@headerContent, "#include \"StringHash.h\"\n");
    push(@headerContent, "#include \"V8Index.h\"\n");
    push(@headerContent, GetHeaderClassInclude($implClassName));
    push(@headerContent, "\nnamespace WebCore {\n");
    if ($podType) {
        push(@headerContent, "\ntemplate<typename PODType> class V8SVGPODTypeWrapper;\n");
    }
    push(@headerContent, "\nclass $className {\n");

    my $nativeType = GetNativeTypeForConversions($interfaceName);
    if ($podType) {
        $nativeType = "V8SVGPODTypeWrapper<${nativeType} >";
    }
    my $forceNewObjectParameter = IsDOMNodeType($interfaceName) ? ", bool forceNewObject = false" : "";
    push(@headerContent, <<END);

 public:
  static bool HasInstance(v8::Handle<v8::Value> value);
  static v8::Persistent<v8::FunctionTemplate> GetRawTemplate();
  static v8::Persistent<v8::FunctionTemplate> GetTemplate();
  static ${nativeType}* toNative(v8::Handle<v8::Object>);
  static v8::Handle<v8::Object> wrap(${nativeType}*${forceNewObjectParameter});
END

    if ($implClassName eq "DOMWindow") {
      push(@headerContent, <<END);
  static v8::Persistent<v8::ObjectTemplate> GetShadowObjectTemplate();
END
    }

    my @enabledAtRuntime;
    foreach my $function (@{$dataNode->functions}) {
        my $name = $function->signature->name;
        my $attrExt = $function->signature->extendedAttributes;

        # FIXME: We should only be generating callback declarations for functions labeled [Custom] or [V8Custom],
        # but we can't do that due to some mislabeled functions in the idl's (https://bugs.webkit.org/show_bug.cgi?id=33066).
        push(@headerContent, <<END);
  static v8::Handle<v8::Value> ${name}Callback(const v8::Arguments&);
END
        if ($attrExt->{"EnabledAtRuntime"}) {
            push(@enabledAtRuntime, $function);
        }
    }

    if ($dataNode->extendedAttributes->{"CustomConstructor"} || $dataNode->extendedAttributes->{"CanBeConstructed"}) {
        push(@headerContent, <<END);
  static v8::Handle<v8::Value> constructorCallback(const v8::Arguments& args);
END
    }

    foreach my $attribute (@{$dataNode->attributes}) {
        my $name = $attribute->signature->name;
        my $attrExt = $attribute->signature->extendedAttributes;
        if ($attrExt->{"V8CustomGetter"} || $attrExt->{"CustomGetter"}
            || $attrExt->{"V8Custom"} || $attrExt->{"Custom"}) {
            push(@headerContent, <<END);
  static v8::Handle<v8::Value> ${name}AccessorGetter(v8::Local<v8::String> name, const v8::AccessorInfo& info);
END
        }
        if ($attrExt->{"V8CustomSetter"} || $attrExt->{"CustomSetter"}
            || $attrExt->{"V8Custom"} || $attrExt->{"Custom"}) {
            push(@headerContent, <<END);
  static void ${name}AccessorSetter(v8::Local<v8::String> name, v8::Local<v8::Value> value, const v8::AccessorInfo& info);
END
        }
        if ($attrExt->{"EnabledAtRuntime"}) {
            push(@enabledAtRuntime, $attribute);
        }
    }

    GenerateHeaderNamedAndIndexedPropertyAccessors($dataNode);
    GenerateHeaderCustomCall($dataNode);
    GenerateHeaderCustomInternalFieldIndices($dataNode);

    if ($dataNode->extendedAttributes->{"CheckDomainSecurity"}) {
        push(@headerContent, <<END);
  static bool namedSecurityCheck(v8::Local<v8::Object> host, v8::Local<v8::Value> key, v8::AccessType, v8::Local<v8::Value> data);
  static bool indexedSecurityCheck(v8::Local<v8::Object> host, uint32_t index, v8::AccessType, v8::Local<v8::Value> data);
END
    }

    push(@headerContent, <<END);
};

  v8::Handle<v8::Value> toV8(${nativeType}*${forceNewObjectParameter});
END
    if (IsRefPtrType($implClassName)) {
        push(@headerContent, <<END);
  v8::Handle<v8::Value> toV8(PassRefPtr<${nativeType} >${forceNewObjectParameter});
END
    }

    push(@headerContent, "}\n\n");
    push(@headerContent, "#endif // $className" . "_H\n");

    push(@headerContent, "#endif // ${conditionalString}\n\n") if $conditionalString;
}

sub GetInternalFields
{
    my $dataNode = shift;
    my $name = $dataNode->name;

    # FIXME: I am hideous and hard-coded.  Make me beautiful.
    return ("cacheIndex", "implementationIndex") if ($name eq "Document") || ($name eq "SVGDocument");
    return ("cacheIndex", "implementationIndex", "markerIndex", "shadowIndex") if $name eq "HTMLDocument";
    return ("cacheIndex") if IsNodeSubType($dataNode);
    return ("cacheIndex") if $name eq "EventSource";
    return ("cacheIndex") if $name eq "XMLHttpRequest";
    return ("cacheIndex") if $name eq "XMLHttpRequestUpload";
    return ("cacheIndex") if $name eq "MessagePort";
    return ("port1Index", "port2Index") if ($name eq "MessageChannel");
    return ("cacheIndex") if $name eq "AbstractWorker";
    return ("abstractWorkerCacheIndex", "cacheIndex") if $name eq "Worker";
    return ("abstractWorkerCacheIndex", "cacheIndex") if $name eq "WorkerContext";
    return ("abstractWorkerCacheIndex", "workerContextCacheIndex", "cacheIndex") if $name eq "DedicatedWorkerContext";
    return ("abstractWorkerCacheIndex", "cacheIndex") if $name eq "SharedWorker";
    return ("abstractWorkerCacheIndex", "workerContextCacheIndex", "cacheIndex") if $name eq "SharedWorkerContext";
    return ("cacheIndex") if $name eq "Notification";
    return ("cacheIndex") if $name eq "IDBRequest";
    return ("cacheIndex") if $name eq "SVGElementInstance";
    return ("consoleIndex", "historyIndex", "locationbarIndex", "menubarIndex", "navigatorIndex", "personalbarIndex",
        "screenIndex", "scrollbarsIndex", "selectionIndex", "statusbarIndex", "toolbarIndex", "locationIndex",
        "domSelectionIndex", "cacheIndex", "enteredIsolatedWorldIndex") if $name eq "DOMWindow";
    return ("cacheIndex") if $name eq "DOMApplicationCache";
    return ("cacheIndex") if $name eq "WebSocket";
    return ("ownerNodeIndex") if ($name eq "StyleSheet") || ($name eq "CSSStyleSheet");
    return ("ownerNodeIndex") if ($name eq "NamedNodeMap");
    return ();
}

sub GetHeaderClassInclude
{
    my $className = shift;
    if ($className =~ /SVGPathSeg/) {
        $className =~ s/Abs|Rel//;
    }
    return "" if (AvoidInclusionOfType($className));
    return "#include \"SVGAnimatedTemplate.h\"\n" if ($codeGenerator->IsSVGAnimatedType($className));
    return "#include \"${className}.h\"\n";
}

sub GenerateHeaderCustomInternalFieldIndices
{
    my $dataNode = shift;
    my @customInternalFields = GetInternalFields($dataNode);
    my $customFieldCounter = 0;
    foreach my $customInternalField (@customInternalFields) {
        push(@headerContent, <<END);
  static const int ${customInternalField} = v8DefaultWrapperInternalFieldCount + ${customFieldCounter};
END
        $customFieldCounter++;
    }
    push(@headerContent, <<END);
  static const int internalFieldCount = v8DefaultWrapperInternalFieldCount + ${customFieldCounter};
END
}

my %indexerSpecialCases = (
    "Storage" => 1,
    "HTMLAppletElement" => 1,
    "HTMLDocument" => 1,
    "HTMLEmbedElement" => 1,
    "HTMLObjectElement" => 1
);

sub GenerateHeaderNamedAndIndexedPropertyAccessors
{
    my $dataNode = shift;
    my $interfaceName = $dataNode->name;
    my $hasCustomIndexedGetter = $dataNode->extendedAttributes->{"HasIndexGetter"} || $dataNode->extendedAttributes->{"CustomGetOwnPropertySlot"};
    my $hasCustomIndexedSetter = $dataNode->extendedAttributes->{"HasCustomIndexSetter"} && !$dataNode->extendedAttributes->{"HasNumericIndexGetter"};
    my $hasCustomNamedGetter = $dataNode->extendedAttributes->{"HasNameGetter"} || $dataNode->extendedAttributes->{"HasOverridingNameGetter"} || $dataNode->extendedAttributes->{"CustomGetOwnPropertySlot"};
    my $hasCustomNamedSetter = $dataNode->extendedAttributes->{"DelegatingPutFunction"};
    my $hasCustomDeleters = $dataNode->extendedAttributes->{"CustomDeleteProperty"};
    my $hasCustomEnumerator = $dataNode->extendedAttributes->{"CustomGetPropertyNames"};
    if ($interfaceName eq "HTMLOptionsCollection") {
        $interfaceName = "HTMLCollection";
        $hasCustomIndexedGetter = 1;
        $hasCustomNamedGetter = 1;
    }
    if ($interfaceName eq "DOMWindow") {
        $hasCustomDeleterr = 0;
        $hasEnumerator = 0;
    }
    if ($interfaceName eq "HTMLSelectElement") {
        $hasCustomNamedGetter = 1;
    }
    my $isIndexerSpecialCase = exists $indexerSpecialCases{$interfaceName};

    if ($hasCustomIndexedGetter || $isIndexerSpecialCase) {
        push(@headerContent, <<END);
  static v8::Handle<v8::Value> indexedPropertyGetter(uint32_t index, const v8::AccessorInfo& info);
END
    }

    if ($isIndexerSpecialCase || $hasCustomIndexedSetter) {
        push(@headerContent, <<END);
  static v8::Handle<v8::Value> indexedPropertySetter(uint32_t index, v8::Local<v8::Value> value, const v8::AccessorInfo& info);
END
    }
    if ($hasCustomDeleters) {
        push(@headerContent, <<END);
  static v8::Handle<v8::Boolean> indexedPropertyDeleter(uint32_t index, const v8::AccessorInfo& info);
END
    }
    if ($hasCustomNamedGetter) {
        push(@headerContent, <<END);
  static v8::Handle<v8::Value> namedPropertyGetter(v8::Local<v8::String> name, const v8::AccessorInfo& info);
END
    }
    if ($hasCustomNamedSetter) {
        push(@headerContent, <<END);
  static v8::Handle<v8::Value> namedPropertySetter(v8::Local<v8::String> name, v8::Local<v8::Value> value, const v8::AccessorInfo& info);
END
    }
    if ($hasCustomDeleters || $interfaceName eq "HTMLDocument") {
        push(@headerContent, <<END);
  static v8::Handle<v8::Boolean> namedPropertyDeleter(v8::Local<v8::String> name, const v8::AccessorInfo& info);
END
    }
    if ($hasCustomEnumerator) {
        push(@headerContent, <<END);
  static v8::Handle<v8::Array> namedPropertyEnumerator(const v8::AccessorInfo& info);
END
    }
}

sub GenerateHeaderCustomCall
{
    my $dataNode = shift;

    if ($dataNode->extendedAttributes->{"CustomCall"}) {
        push(@headerContent, "  static v8::Handle<v8::Value> callAsFunctionCallback(const v8::Arguments&);\n");
    }
    if ($dataNode->name eq "Event") {
        push(@headerContent, "  static v8::Handle<v8::Value> dataTransferAccessorGetter(v8::Local<v8::String> name, const v8::AccessorInfo& info);\n");
        push(@headerContent, "  static void valueAccessorSetter(v8::Local<v8::String> name, v8::Local<v8::Value> value, const v8::AccessorInfo& info);\n");
    }
    if ($dataNode->name eq "Location") {
        push(@headerContent, "  static v8::Handle<v8::Value> assignAccessorGetter(v8::Local<v8::String> name, const v8::AccessorInfo& info);\n");
        push(@headerContent, "  static v8::Handle<v8::Value> reloadAccessorGetter(v8::Local<v8::String> name, const v8::AccessorInfo& info);\n");
        push(@headerContent, "  static v8::Handle<v8::Value> replaceAccessorGetter(v8::Local<v8::String> name, const v8::AccessorInfo& info);\n");
    }
}

sub GenerateSetDOMException
{
    my $indent = shift;
    my $result = "";

    $result .= $indent . "if (UNLIKELY(ec)) {\n";
    $result .= $indent . "    V8Proxy::setDOMException(ec);\n";
    $result .= $indent . "    return v8::Handle<v8::Value>();\n";
    $result .= $indent . "}\n";

    return $result;
}

sub IsSubType
{
    my $dataNode = shift;
    my $parentType = shift;
    return 1 if ($dataNode->name eq $parentType);
    foreach (@allParents) {
        my $parent = $codeGenerator->StripModule($_);
        return 1 if $parent eq $parentType;
    }
    return 0;
}

sub IsNodeSubType
{
    my $dataNode = shift;
    return IsSubType($dataNode, "Node");
}

sub IsEventSubType
{
    my $dataNode = shift;
    return IsSubType($dataNode, "Event");
}

sub GenerateDomainSafeFunctionGetter
{
    my $function = shift;
    my $dataNode = shift;
    my $implClassName = shift;

    my $className = "V8" . $dataNode->name;
    my $funcName = $function->signature->name;

    my $signature = "v8::Signature::New(" . $className . "::GetRawTemplate())";
    if ($function->signature->extendedAttributes->{"V8DoNotCheckSignature"}) {
        $signature = "v8::Local<v8::Signature>()";
    }

    my $newTemplateString = GenerateNewFunctionTemplate($function, $dataNode, $signature);

    push(@implContentDecls, <<END);
  static v8::Handle<v8::Value> ${funcName}AttrGetter(v8::Local<v8::String> name, const v8::AccessorInfo& info) {
    INC_STATS(\"DOM.$implClassName.$funcName._get\");
    static v8::Persistent<v8::FunctionTemplate> private_template =
        v8::Persistent<v8::FunctionTemplate>::New($newTemplateString);
    v8::Handle<v8::Object> holder = V8DOMWrapper::lookupDOMWrapper(${className}::GetTemplate(), info.This());
    if (holder.IsEmpty()) {
      // can only reach here by 'object.__proto__.func', and it should passed
      // domain security check already
      return private_template->GetFunction();
    }
    ${implClassName}* imp = ${className}::toNative(holder);
    if (!V8BindingSecurity::canAccessFrame(V8BindingState::Only(), imp->frame(), false)) {
      static v8::Persistent<v8::FunctionTemplate> shared_template =
        v8::Persistent<v8::FunctionTemplate>::New($newTemplateString);
      return shared_template->GetFunction();

    } else {
      return private_template->GetFunction();
    }
  }

END
}

sub GenerateConstructorGetter
{
    my $implClassName = shift;
    my $classIndex = shift;

    push(@implContentDecls, <<END);
  static v8::Handle<v8::Value> ${implClassName}ConstructorGetter(v8::Local<v8::String> name, const v8::AccessorInfo& info) {
    INC_STATS(\"DOM.$implClassName.constructors._get\");
    v8::Handle<v8::Value> data = info.Data();
    ASSERT(data->IsNumber());
    V8ClassIndex::V8WrapperType type = V8ClassIndex::FromInt(data->Int32Value());
END

    if ($classIndex eq "DOMWINDOW") {
        push(@implContentDecls, <<END);
    // Get the proxy corresponding to the DOMWindow if possible to
    // make sure that the constructor function is constructed in the
    // context of the DOMWindow and not in the context of the caller.
    return V8DOMWrapper::getConstructor(type, V8DOMWindow::toNative(info.Holder()));
END
    } elsif ($classIndex eq "DEDICATEDWORKERCONTEXT" or $classIndex eq "WORKERCONTEXT" or $classIndex eq "SHAREDWORKERCONTEXT") {
        push(@implContentDecls, <<END);
    return V8DOMWrapper::getConstructor(type, V8WorkerContext::toNative(info.Holder()));
END
    } else {
        push(@implContentDecls, "    return v8::Handle<v8::Value>();");
    }

    push(@implContentDecls, <<END);

    }

END
}

sub GenerateNormalAttrGetter
{
    my $attribute = shift;
    my $dataNode = shift;
    my $implClassName = shift;
    my $interfaceName = shift;

    my $attrExt = $attribute->signature->extendedAttributes;

    my $attrName = $attribute->signature->name;

    my $attrType = GetTypeFromSignature($attribute->signature);
    my $attrIsPodType = IsPodType($attrType);

    my $nativeType = GetNativeTypeFromSignature($attribute->signature, -1);
    my $isPodType = IsPodType($implClassName);
    my $skipContext = 0;


    if ($isPodType) {
        $implClassName = GetNativeType($implClassName);
        $implIncludes{"V8SVGPODTypeWrapper.h"} = 1;
    }

    # Special case: SVGZoomEvent's attributes are all read-only
    if ($implClassName eq "SVGZoomEvent") {
        $attrIsPodType = 0;
        $skipContext = 1;
    }

    # Special case: SVGSVGEelement::viewport is read-only
    if (($implClassName eq "SVGSVGElement") and ($attrName eq "viewport")) {
        $attrIsPodType = 0;
        $skipContext = 1;
    }

    # Special case for SVGColor
    if (($implClassName eq "SVGColor") and ($attrName eq "rgbColor")) {
        $attrIsPodType = 0;
    }

    my $getterStringUsesImp = $implClassName ne "float";

  # Getter
    push(@implContentDecls, <<END);
  static v8::Handle<v8::Value> ${attrName}AttrGetter(v8::Local<v8::String> name, const v8::AccessorInfo& info) {
    INC_STATS(\"DOM.$implClassName.$attrName._get\");
END

    if ($isPodType) {
        push(@implContentDecls, <<END);
    V8SVGPODTypeWrapper<$implClassName>* imp_wrapper = V8SVGPODTypeWrapper<$implClassName>::toNative(info.Holder());
    $implClassName imp_instance = *imp_wrapper;
END
        if ($getterStringUsesImp) {
            push(@implContentDecls, <<END);
    $implClassName* imp = &imp_instance;
END
        }

    } elsif ($attrExt->{"v8OnProto"} || $attrExt->{"V8DisallowShadowing"}) {
      if ($interfaceName eq "DOMWindow") {
        push(@implContentDecls, <<END);
    v8::Handle<v8::Object> holder = info.Holder();
END
      } else {
        # perform lookup first
        push(@implContentDecls, <<END);
    v8::Handle<v8::Object> holder = V8DOMWrapper::lookupDOMWrapper(V8${interfaceName}::GetTemplate(), info.This());
    if (holder.IsEmpty()) return v8::Handle<v8::Value>();
END
      }
    push(@implContentDecls, <<END);
    ${implClassName}* imp = V8${implClassName}::toNative(holder);
END
    } else {
        my $reflect = $attribute->signature->extendedAttributes->{"Reflect"};
        if ($getterStringUsesImp && $reflect && IsNodeSubType($dataNode) && $codeGenerator->IsStringType($attrType)) {
            # Generate super-compact call for regular attribute getter:
            my $contentAttributeName = $reflect eq "1" ? $attrName : $reflect;
            my $namespace = $codeGenerator->NamespaceForAttributeName($interfaceName, $contentAttributeName);
            $implIncludes{"${namespace}.h"} = 1;
            push(@implContentDecls, "    return getElementStringAttr(info, ${namespace}::${contentAttributeName}Attr);\n");
            push(@implContentDecls, "  }\n\n");
            return;
            # Skip the rest of the function!
        }
        push(@implContentDecls, <<END);
    ${implClassName}* imp = V8${implClassName}::toNative(info.Holder());
END
    }

    # Generate security checks if necessary
    if ($attribute->signature->extendedAttributes->{"CheckNodeSecurity"}) {
        push(@implContentDecls, "    if (!V8BindingSecurity::checkNodeSecurity(V8BindingState::Only(), imp->$attrName())) return v8::Handle<v8::Value>();\n\n");
    } elsif ($attribute->signature->extendedAttributes->{"CheckFrameSecurity"}) {
        push(@implContentDecls, "    if (!V8BindingSecurity::checkNodeSecurity(V8BindingState::Only(), imp->contentDocument())) return v8::Handle<v8::Value>();\n\n");
    }

    my $useExceptions = 1 if @{$attribute->getterExceptions} and !($isPodType);
    if ($useExceptions) {
        $implIncludes{"ExceptionCode.h"} = 1;
        push(@implContentDecls, "    ExceptionCode ec = 0;\n");
    }

    if ($attribute->signature->extendedAttributes->{"v8referenceattr"}) {
        $attrName = $attribute->signature->extendedAttributes->{"v8referenceattr"};
    }

    my $getterFunc = $codeGenerator->WK_lcfirst($attrName);

    if ($codeGenerator->IsSVGAnimatedType($attribute->signature->type)) {
        # Some SVGFE*Element.idl use 'operator' as attribute name; rewrite as '_operator' to avoid clashes with C/C++
        $getterFunc = "_" . $getterFunc if ($attrName =~ /operator/);
        $getterFunc .= "Animated";
    }

    my $returnType = GetTypeFromSignature($attribute->signature);

    my $getterString;
    if ($getterStringUsesImp) {
        my $reflect = $attribute->signature->extendedAttributes->{"Reflect"};
        my $reflectURL = $attribute->signature->extendedAttributes->{"ReflectURL"};
        if ($reflect || $reflectURL) {
            my $contentAttributeName = ($reflect || $reflectURL) eq "1" ? $attrName : ($reflect || $reflectURL);
            my $namespace = $codeGenerator->NamespaceForAttributeName($interfaceName, $contentAttributeName);
            $implIncludes{"${namespace}.h"} = 1;
            my $getAttributeFunctionName = $reflectURL ? "getURLAttribute" : "getAttribute";
            $getterString = "imp->$getAttributeFunctionName(${namespace}::${contentAttributeName}Attr";
        } else {
            $getterString = "imp->$getterFunc(";
        }
        $getterString .= "ec" if $useExceptions;
        $getterString .= ")";
        if ($nativeType eq "int" and $attribute->signature->extendedAttributes->{"ConvertFromString"}) {
            $getterString .= ".toInt()";
        }
    } else {
        $getterString = "imp_instance";
    }

    my $result;
    my $wrapper;

    if ($attrIsPodType) {
        $implIncludes{"V8SVGPODTypeWrapper.h"} = 1;

        my $getter = $getterString;
        $getter =~ s/imp->//;
        $getter =~ s/\(\)//;
        my $setter = "set" . $codeGenerator->WK_ucfirst($getter);

        my $implClassIsAnimatedType = $codeGenerator->IsSVGAnimatedType($implClassName);
        if (not $implClassIsAnimatedType and $codeGenerator->IsPodTypeWithWriteableProperties($attrType) and not defined $attribute->signature->extendedAttributes->{"Immutable"}) {
            if (IsPodType($implClassName)) {
                my $wrapper = "V8SVGStaticPODTypeWrapperWithPODTypeParent<$nativeType, $implClassName>::create($getterString, imp_wrapper)";
                push(@implContentDecls, "    RefPtr<V8SVGStaticPODTypeWrapperWithPODTypeParent<$nativeType, $implClassName> > wrapper = $wrapper;\n");
            } else {
                my $wrapper = "V8SVGStaticPODTypeWrapperWithParent<$nativeType, $implClassName>::create(imp, &${implClassName}::$getter, &${implClassName}::$setter)";
                push(@implContentDecls, "    RefPtr<V8SVGStaticPODTypeWrapperWithParent<$nativeType, $implClassName> > wrapper = $wrapper;\n");
            }
        } else {
            if ($implClassIsAnimatedType) {
                # We can't hash member function pointers, so instead generate
                # some hashing material based on the names of the methods.
                my $hashhex = substr(Digest::MD5::md5_hex("${implClassName}::$getter ${implClassName}::$setter)"), 0, 8);
                my $wrapper = "V8SVGDynamicPODTypeWrapperCache<$nativeType, $implClassName>::lookupOrCreateWrapper(imp, &${implClassName}::$getter, &${implClassName}::$setter, 0x$hashhex)";
                push(@implContentDecls, "    RefPtr<V8SVGPODTypeWrapper<" . $nativeType . "> > wrapper = $wrapper;\n");
            } else {
                my $wrapper = GenerateSVGStaticPodTypeWrapper($returnType, $getterString);
                push(@implContentDecls, "    RefPtr<V8SVGStaticPODTypeWrapper<" . $nativeType . "> > wrapper = $wrapper;\n");
            }
        }

    } else {
        if ($attribute->signature->type eq "EventListener" && $dataNode->name eq "DOMWindow") {
            push(@implContentDecls, "    if (!imp->document())\n");
            push(@implContentDecls, "      return v8::Handle<v8::Value>();\n");
        }

        if ($useExceptions) {
            push(@implContentDecls, "    $nativeType v = ");
            push(@implContentDecls, "$getterString;\n");
            push(@implContentDecls, GenerateSetDOMException("    "));
            $result = "v";
            $result .= ".release()" if (IsRefPtrType($returnType));
        } else {
            # Can inline the function call into the return statement to avoid overhead of using a Ref<> temporary
            $result = $getterString;
        }
    }

    if (IsSVGTypeNeedingContextParameter($attrType) && !$skipContext) {
        if ($attrIsPodType) {
            push(@implContentDecls, GenerateSVGContextAssignment($implClassName, "wrapper.get()", "    "));
        } else {
            push(@implContentDecls, GenerateSVGContextRetrieval($implClassName, "    "));
            # The templating associated with passing withSVGContext()'s return value directly into toV8 can get compilers confused,
            # so just manually set the return value to a PassRefPtr of the expected type.
            push(@implContentDecls, "    PassRefPtr<$attrType> resultAsPassRefPtr = V8Proxy::withSVGContext($result, context);\n");
            $result = "resultAsPassRefPtr";
        }
    }

    if ($attrIsPodType) {
        $implIncludes{"V8${attrType}.h"} = 1;
        push(@implContentDecls, "    return toV8(wrapper.release().get());\n");
    } else {
        push(@implContentDecls, "    " . ReturnNativeToJSValue($attribute->signature, $result, "    ").";\n");
    }

    push(@implContentDecls, "  }\n\n");  # end of getter
}


sub GenerateReplaceableAttrSetter
{
    my $implClassName = shift;

    push(@implContentDecls,
       "  static void ${attrName}AttrSetter(v8::Local<v8::String> name," .
       " v8::Local<v8::Value> value, const v8::AccessorInfo& info) {\n");

    push(@implContentDecls, "    INC_STATS(\"DOM.$implClassName.$attrName._set\");\n");

    push(@implContentDecls, "    v8::Local<v8::String> ${attrName}_string = v8::String::New(\"${attrName}\");\n");
    push(@implContentDecls, "    info.Holder()->Delete(${attrName}_string);\n");
    push(@implContentDecls, "    info.This()->Set(${attrName}_string, value);\n");
    push(@implContentDecls, "  }\n\n");
}


sub GenerateNormalAttrSetter
{
    my $attribute = shift;
    my $dataNode = shift;
    my $implClassName = shift;
    my $interfaceName = shift;

    my $attrExt = $attribute->signature->extendedAttributes;

    push(@implContentDecls,
       "  static void ${attrName}AttrSetter(v8::Local<v8::String> name," .
       " v8::Local<v8::Value> value, const v8::AccessorInfo& info) {\n");

    push(@implContentDecls, "    INC_STATS(\"DOM.$implClassName.$attrName._set\");\n");

    my $isPodType = IsPodType($implClassName);

    if ($isPodType) {
        $implClassName = GetNativeType($implClassName);
        $implIncludes{"V8SVGPODTypeWrapper.h"} = 1;
        push(@implContentDecls, "    V8SVGPODTypeWrapper<$implClassName>* wrapper = V8SVGPODTypeWrapper<$implClassName>::toNative(info.Holder());\n");
        push(@implContentDecls, "    $implClassName imp_instance = *wrapper;\n");
        push(@implContentDecls, "    $implClassName* imp = &imp_instance;\n");

    } elsif ($attrExt->{"v8OnProto"}) {
      if ($interfaceName eq "DOMWindow") {
        push(@implContentDecls, <<END);
    v8::Handle<v8::Object> holder = info.Holder();
END
      } else {
        # perform lookup first
        push(@implContentDecls, <<END);
    v8::Handle<v8::Object> holder = V8DOMWrapper::lookupDOMWrapper(V8${interfaceName}::GetTemplate(), info.This());
    if (holder.IsEmpty()) return;
END
      }
    push(@implContentDecls, <<END);
    ${implClassName}* imp = V8${implClassName}::toNative(holder);
END
    } else {
        my $attrType = GetTypeFromSignature($attribute->signature);
        my $reflect = $attribute->signature->extendedAttributes->{"Reflect"};
        my $reflectURL = $attribute->signature->extendedAttributes->{"ReflectURL"};
        if (($reflect || $reflectURL) && IsNodeSubType($dataNode) && $codeGenerator->IsStringType($attrType)) {
            # Generate super-compact call for regular attribute setter:
            my $contentAttributeName = ($reflect || $reflectURL) eq "1" ? $attrName : ($reflect || $reflectURL);
            my $namespace = $codeGenerator->NamespaceForAttributeName($interfaceName, $contentAttributeName);
            $implIncludes{"${namespace}.h"} = 1;
            push(@implContentDecls, "    setElementStringAttr(info, ${namespace}::${contentAttributeName}Attr, value);\n");
            push(@implContentDecls, "  }\n\n");
            return;
            # Skip the rest of the function!
        }

        push(@implContentDecls, <<END);
    ${implClassName}* imp = V8${implClassName}::toNative(info.Holder());
END
    }

    my $nativeType = GetNativeTypeFromSignature($attribute->signature, 0);
    if ($attribute->signature->type eq "EventListener") {
        if ($dataNode->name eq "DOMWindow") {
            push(@implContentDecls, "    if (!imp->document())\n");
            push(@implContentDecls, "      return;\n");
        }
    } else {
        push(@implContentDecls, "    $nativeType v = " . JSValueToNative($attribute->signature, "value") . ";\n");
    }

    my $result = "";
    if ($nativeType eq "int" and $attribute->signature->extendedAttributes->{"ConvertFromString"}) {
        $result .= "WebCore::String::number(";
    }
    $result .= "v";
    if ($nativeType eq "int" and $attribute->signature->extendedAttributes->{"ConvertFromString"}) {
        $result .= ")";
    }
    my $returnType = GetTypeFromSignature($attribute->signature);
    if (IsRefPtrType($returnType)) {
        $result = "WTF::getPtr(" . $result . ")";
    }

    my $useExceptions = 1 if @{$attribute->setterExceptions} and !($isPodType);

    if ($useExceptions) {
        $implIncludes{"ExceptionCode.h"} = 1;
        push(@implContentDecls, "    ExceptionCode ec = 0;\n");
    }

    if ($implClassName eq "float") {
        push(@implContentDecls, "    *imp = $result;\n");
    } else {
        my $implSetterFunctionName = $codeGenerator->WK_ucfirst($attrName);
        my $reflect = $attribute->signature->extendedAttributes->{"Reflect"};
        my $reflectURL = $attribute->signature->extendedAttributes->{"ReflectURL"};
        if ($reflect || $reflectURL) {
            my $contentAttributeName = ($reflect || $reflectURL) eq "1" ? $attrName : ($reflect || $reflectURL);
            my $namespace = $codeGenerator->NamespaceForAttributeName($interfaceName, $contentAttributeName);
            $implIncludes{"${namespace}.h"} = 1;
            push(@implContentDecls, "    imp->setAttribute(${namespace}::${contentAttributeName}Attr, $result");
        } elsif ($attribute->signature->type eq "EventListener") {
            $implIncludes{"V8AbstractEventListener.h"} = 1;
            push(@implContentDecls, "    transferHiddenDependency(info.Holder(), imp->$attrName(), value, V8${interfaceName}::cacheIndex);\n");
            push(@implContentDecls, "    imp->set$implSetterFunctionName(V8DOMWrapper::getEventListener(imp, value, true, ListenerFindOrCreate)");
        } else {
            push(@implContentDecls, "    imp->set$implSetterFunctionName($result");
        }
        push(@implContentDecls, ", ec") if $useExceptions;
        push(@implContentDecls, ");\n");
    }

    if ($useExceptions) {
        push(@implContentDecls, "    if (UNLIKELY(ec))\n");
        push(@implContentDecls, "        V8Proxy::setDOMException(ec);\n");
    }

    if ($isPodType) {
        push(@implContentDecls, "    wrapper->commitChange(*imp, V8Proxy::svgContext(wrapper));\n");
    } elsif (IsSVGTypeNeedingContextParameter($implClassName)) {
        $implIncludes{"SVGElement.h"} = 1;

        my $currentObject = "imp";
        if ($isPodType) {
            $currentObject = "wrapper";
        }

        push(@implContentDecls, "    if (SVGElement* context = V8Proxy::svgContext($currentObject)) {\n");
        push(@implContentDecls, "        context->svgAttributeChanged(imp->associatedAttributeName());\n");
        push(@implContentDecls, "    }\n");
    }

    push(@implContentDecls, "    return;\n");
    push(@implContentDecls, "  }\n\n");  # end of setter
}

sub GetFunctionTemplateCallbackName
{
    $function = shift;
    $dataNode = shift;

    my $interfaceName = $dataNode->name;
    my $name = $function->signature->name;

    if ($function->signature->extendedAttributes->{"Custom"} ||
        $function->signature->extendedAttributes->{"V8Custom"}) {
        if ($function->signature->extendedAttributes->{"Custom"} &&
            $function->signature->extendedAttributes->{"V8Custom"}) {
            die "Custom and V8Custom should be mutually exclusive!"
        }
        return "V8${interfaceName}::${name}Callback";
    } else {
        return "${interfaceName}Internal::${name}Callback";
    }
}

sub GenerateNewFunctionTemplate
{
    $function = shift;
    $dataNode = shift;
    $signature = shift;

    my $callback = GetFunctionTemplateCallbackName($function, $dataNode);
    return "v8::FunctionTemplate::New($callback, v8::Handle<v8::Value>(), $signature)";
}

sub GenerateFunctionCallback
{
    my $function = shift;
    my $dataNode = shift;
    my $classIndex = shift;
    my $implClassName = shift;

    my $interfaceName = $dataNode->name;
    my $name = $function->signature->name;

    push(@implContentDecls,
"  static v8::Handle<v8::Value> ${name}Callback(const v8::Arguments& args) {\n" .
"    INC_STATS(\"DOM.$implClassName.$name\");\n");

    my $numParameters = @{$function->parameters};

    if ($function->signature->extendedAttributes->{"RequiresAllArguments"}) {
        push(@implContentDecls,
            "    if (args.Length() < $numParameters) return v8::Handle<v8::Value>();\n");
    }

    if (IsPodType($implClassName)) {
        my $nativeClassName = GetNativeType($implClassName);
        push(@implContentDecls, "    V8SVGPODTypeWrapper<$nativeClassName>* imp_wrapper = V8SVGPODTypeWrapper<$nativeClassName>::toNative(args.Holder());\n");
        push(@implContentDecls, "    $nativeClassName imp_instance = *imp_wrapper;\n");
        push(@implContentDecls, "    $nativeClassName* imp = &imp_instance;\n");
    } else {
        push(@implContentDecls, <<END);
    ${implClassName}* imp = V8${implClassName}::toNative(args.Holder());
END
    }

  # Check domain security if needed
    if (($dataNode->extendedAttributes->{"CheckDomainSecurity"}
       || $interfaceName eq "DOMWindow")
       && !$function->signature->extendedAttributes->{"DoNotCheckDomainSecurity"}) {
    # We have not find real use cases yet.
    push(@implContentDecls,
"    if (!V8BindingSecurity::canAccessFrame(V8BindingState::Only(), imp->frame(), true)) {\n".
"      return v8::Handle<v8::Value>();\n" .
"    }\n");
    }

    my $raisesExceptions = @{$function->raisesExceptions};
    if (!$raisesExceptions) {
        foreach my $parameter (@{$function->parameters}) {
            if (TypeCanFailConversion($parameter) or $parameter->extendedAttributes->{"IsIndex"}) {
                $raisesExceptions = 1;
            }
        }
    }

    if ($raisesExceptions) {
        $implIncludes{"ExceptionCode.h"} = 1;
        push(@implContentDecls, "    ExceptionCode ec = 0;\n");
        push(@implContentDecls, "    {\n");
        # The brace here is needed to prevent the ensuing 'goto fail's from jumping past constructors
        # of objects (like Strings) declared later, causing compile errors. The block scope ends
        # right before the label 'fail:'.
    }

    if ($function->signature->extendedAttributes->{"CustomArgumentHandling"}) {
        push(@implContentDecls,
"    OwnPtr<ScriptCallStack> callStack(ScriptCallStack::create(args, $numParameters));\n".
"    if (!callStack)\n".
"        return v8::Undefined();\n");
        $implIncludes{"ScriptCallStack.h"} = 1;
    }
    if ($function->signature->extendedAttributes->{"SVGCheckSecurityDocument"}) {
        push(@implContentDecls,
"    if (!V8BindingSecurity::checkNodeSecurity(V8BindingState::Only(), imp->getSVGDocument(ec)))\n" .
"      return v8::Handle<v8::Value>();\n");
    }

    my $paramIndex = 0;
    foreach my $parameter (@{$function->parameters}) {
        TranslateParameter($parameter);

        my $parameterName = $parameter->name;

        if ($parameter->extendedAttributes->{"Optional"}) {
            # Generate early call if there are not enough parameters.
            push(@implContentDecls, "    if (args.Length() <= $paramIndex) {\n");
            my $functionCall = GenerateFunctionCallString($function, $paramIndex, "    " x 2, $implClassName);
            push(@implContentDecls, $functionCall);
            push(@implContentDecls, "    }\n");
        }

        if (BasicTypeCanFailConversion($parameter)) {
            push(@implContentDecls, "    bool ${parameterName}Ok;\n");
        }

        push(@implContentDecls, "    " . GetNativeTypeFromSignature($parameter, $paramIndex) . " $parameterName = ");
        push(@implContentDecls, JSValueToNative($parameter, "args[$paramIndex]",
           BasicTypeCanFailConversion($parameter) ?  "${parameterName}Ok" : undef) . ";\n");

        if (TypeCanFailConversion($parameter)) {
            $implIncludes{"ExceptionCode.h"} = 1;
            push(@implContentDecls,
"    if (UNLIKELY(!$parameterName" . (BasicTypeCanFailConversion($parameter) ? "Ok" : "") . ")) {\n" .
"      ec = TYPE_MISMATCH_ERR;\n" .
"      goto fail;\n" .
"    }\n");
        }

        if ($parameter->extendedAttributes->{"IsIndex"}) {
            $implIncludes{"ExceptionCode.h"} = 1;
            push(@implContentDecls,
"    if (UNLIKELY($parameterName < 0)) {\n" .
"      ec = INDEX_SIZE_ERR;\n" .
"      goto fail;\n" .
"    }\n");
        }

        $paramIndex++;
    }

    # Build the function call string.
    my $callString = GenerateFunctionCallString($function, $paramIndex, "    ", $implClassName);
    push(@implContentDecls, "$callString");

    if ($raisesExceptions) {
        push(@implContentDecls, "    }\n");
        push(@implContentDecls, "  fail:\n");
        push(@implContentDecls, "    V8Proxy::setDOMException(ec);\n");
        push(@implContentDecls, "    return v8::Handle<v8::Value>();\n");
    }

    push(@implContentDecls, "  }\n\n");
}

sub GenerateBatchedAttributeData
{
    my $dataNode = shift;
    my $interfaceName = $dataNode->name;
    my $attributes = shift;

    foreach my $attribute (@$attributes) {
        my $conditionalString = GenerateConditionalString($attribute->signature);
        push(@implContent, "\n#if ${conditionalString}\n") if $conditionalString;
        GenerateSingleBatchedAttribute($interfaceName, $attribute, ",", "");
        push(@implContent, "\n#endif // ${conditionalString}\n") if $conditionalString;
    }
}

sub GenerateSingleBatchedAttribute
{
    my $interfaceName = shift;
    my $attribute = shift;
    my $delimiter = shift;
    my $indent = shift;
    my $attrName = $attribute->signature->name;
    my $attrExt = $attribute->signature->extendedAttributes;

    my $accessControl = "v8::DEFAULT";
    if ($attrExt->{"DoNotCheckDomainSecurityOnGet"}) {
        $accessControl = "v8::ALL_CAN_READ";
    } elsif ($attrExt->{"DoNotCheckDomainSecurityOnSet"}) {
        $accessControl = "v8::ALL_CAN_WRITE";
    } elsif ($attrExt->{"DoNotCheckDomainSecurity"}) {
        $accessControl = "v8::ALL_CAN_READ";
        if (!($attribute->type =~ /^readonly/) && !($attrExt->{"V8ReadOnly"})) {
            $accessControl .= "|v8::ALL_CAN_WRITE";
        }
    }
    if ($attrExt->{"V8DisallowShadowing"}) {
        $accessControl .= "|v8::PROHIBITS_OVERWRITING";
    }
    $accessControl = "static_cast<v8::AccessControl>(" . $accessControl . ")";

    my $customAccessor =
        $attrExt->{"Custom"} ||
        $attrExt->{"CustomSetter"} ||
        $attrExt->{"CustomGetter"} ||
        $attrExt->{"V8Custom"} ||
        $attrExt->{"V8CustomSetter"} ||
        $attrExt->{"V8CustomGetter"} ||
        "";
    if ($customAccessor eq 1) {
        # use the naming convension, interface + (capitalize) attr name
        $customAccessor = $interfaceName . "::" . $attrName;
    }

    my $getter;
    my $setter;
    my $propAttr = "v8::None";
    my $hasCustomSetter = 0;

    # Check attributes.
    if ($attrExt->{"DontEnum"}) {
        $propAttr .= "|v8::DontEnum";
    }
    if ($attrExt->{"V8DisallowShadowing"}) {
        $propAttr .= "|v8::DontDelete";
    }

    my $on_proto = "0 /* on instance */";
    my $data = "V8ClassIndex::INVALID_CLASS_INDEX /* no data */";

    # Constructor
    if ($attribute->signature->type =~ /Constructor$/) {
        my $constructorType = $codeGenerator->StripModule($attribute->signature->type);
        $constructorType =~ s/Constructor$//;
        my $constructorIndex = uc($constructorType);
        if ($customAccessor) {
            $getter = "V8${customAccessor}AccessorGetter";
        } else {
            $data = "V8ClassIndex::${constructorIndex}";
            $getter = "${interfaceName}Internal::${interfaceName}ConstructorGetter";
        }
        $setter = "0";
        $propAttr = "v8::ReadOnly";

    } else {
        # Default Getter and Setter
        $getter = "${interfaceName}Internal::${attrName}AttrGetter";
        $setter = "${interfaceName}Internal::${attrName}AttrSetter";

        # Custom Setter
        if ($attrExt->{"CustomSetter"} || $attrExt->{"V8CustomSetter"} || $attrExt->{"Custom"} || $attrExt->{"V8Custom"}) {
            $hasCustomSetter = 1;
            $setter = "V8${customAccessor}AccessorSetter";
        }

        # Custom Getter
        if ($attrExt->{"CustomGetter"} || $attrExt->{"V8CustomGetter"} || $attrExt->{"Custom"} || $attrExt->{"V8Custom"}) {
            $getter = "V8${customAccessor}AccessorGetter";
        }
    }

    # Replaceable
    if ($attrExt->{"Replaceable"} && !$hasCustomSetter) {
        $setter = "0";
        # Handle the special case of window.top being marked as Replaceable.
        # FIXME: Investigate whether we could treat window.top as replaceable
        # and allow shadowing without it being a security hole.
        if (!($interfaceName eq "DOMWindow" and $attrName eq "top")) {
            $propAttr .= "|v8::ReadOnly";
        }
    }

    # Read only attributes
    if ($attribute->type =~ /^readonly/ || $attrExt->{"V8ReadOnly"}) {
        $setter = "0";
    }

    # An accessor can be installed on the proto
    if ($attrExt->{"v8OnProto"}) {
        $on_proto = "1 /* on proto */";
    }

    my $commentInfo = "Attribute '$attrName' (Type: '" . $attribute->type .
                      "' ExtAttr: '" . join(' ', keys(%{$attrExt})) . "')";

    push(@implContent, $indent . "    {\n");
    push(@implContent, $indent . "        \/\/ $commentInfo\n");
    push(@implContent, $indent . "        \"$attrName\",\n");
    push(@implContent, $indent . "        $getter,\n");
    push(@implContent, $indent . "        $setter,\n");
    push(@implContent, $indent . "        $data,\n");
    push(@implContent, $indent . "        $accessControl,\n");
    push(@implContent, $indent . "        static_cast<v8::PropertyAttribute>($propAttr),\n");
    push(@implContent, $indent . "        $on_proto\n");
    push(@implContent, $indent . "    }" . $delimiter . "\n");
END
}

sub GenerateImplementationIndexer
{
    my $dataNode = shift;
    my $indexer = shift;
    my $interfaceName = $dataNode->name;

    # FIXME: Figure out what HasNumericIndexGetter is really supposed to do. Right now, it's only set on WebGL-related files.
    my $hasCustomSetter = $dataNode->extendedAttributes->{"HasCustomIndexSetter"} && !$dataNode->extendedAttributes->{"HasNumericIndexGetter"};
    my $hasGetter = $dataNode->extendedAttributes->{"HasIndexGetter"} || $dataNode->extendedAttributes->{"CustomGetOwnPropertySlot"};

    # FIXME: Find a way to not have to special-case HTMLOptionsCollection.
    if ($interfaceName eq "HTMLOptionsCollection") {
        $hasGetter = 1;
    }
    # FIXME: If the parent interface of $dataNode already has
    # HasIndexGetter, we don't need to handle the getter here.
    if ($interfaceName eq "WebKitCSSTransformValue") {
        $hasGetter = 0;
    }

    # FIXME: Investigate and remove this nastinesss. In V8, named property handling and indexer handling are apparently decoupled,
    # which means that object[X] where X is a number doesn't reach named property indexer. So we need to provide
    # simplistic, mirrored indexer handling in addition to named property handling.
    my $isSpecialCase = exists $indexerSpecialCases{$interfaceName};
    if ($isSpecialCase) {
        $hasGetter = 1;
        if ($dataNode->extendedAttributes->{"DelegatingPutFunction"}) {
            $hasCustomSetter = 1;
        }
    }

    if (!$hasGetter) {
        return;
    }

    $implIncludes{"V8Collection.h"} = 1;

    my $indexerType = $indexer ? $indexer->type : 0;

    # FIXME: Remove this once toV8 helper methods are implemented (see https://bugs.webkit.org/show_bug.cgi?id=32563).
    if ($interfaceName eq "WebKitCSSKeyframesRule") {
        $indexerType = "WebKitCSSKeyframeRule";
    }

    if ($indexerType && !$hasCustomSetter) {
        if ($indexerType eq "DOMString") {
            my $conversion = $indexer->extendedAttributes->{"ConvertNullStringTo"};
            if ($conversion && $conversion eq "Null") {
                push(@implContent, <<END);
  setCollectionStringOrNullIndexedGetter<${interfaceName}>(desc);
END
            } else {
                push(@implContent, <<END);
  setCollectionStringIndexedGetter<${interfaceName}>(desc);
END
            }
        } else {
            my $indexerClassIndex = uc($indexerType);
            push(@implContent, <<END);
  setCollectionIndexedGetter<${interfaceName}, ${indexerType}>(desc, V8ClassIndex::${indexerClassIndex});
END
            # Include the header for this indexer type, because setCollectionIndexedGetter() requires toV8() for this type.
            $implIncludes{"V8${indexerType}.h"} = 1;
        }

        return;
    }

    my $hasDeleter = $dataNode->extendedAttributes->{"CustomDeleteProperty"};
    my $hasEnumerator = !$isSpecialCase && IsNodeSubType($dataNode);
    my $setOn = "Instance";

    # V8 has access-check callback API (see ObjectTemplate::SetAccessCheckCallbacks) and it's used on DOMWindow
    # instead of deleters or enumerators. In addition, the getter should be set on prototype template, to
    # get implementation straight out of the DOMWindow prototype regardless of what prototype is actually set
    # on the object.
    if ($interfaceName eq "DOMWindow") {
        $setOn = "Prototype";
        $hasDeleter = 0;
    }

    push(@implContent, "  desc->${setOn}Template()->SetIndexedPropertyHandler(V8${interfaceName}::indexedPropertyGetter");
    push(@implContent, $hasCustomSetter ? ", V8${interfaceName}::indexedPropertySetter" : ", 0");
    push(@implContent, ", 0"); # IndexedPropertyQuery -- not being used at the moment.
    push(@implContent, $hasDeleter ? ", V8${interfaceName}::indexedPropertyDeleter" : ", 0");
    push(@implContent, ", nodeCollectionIndexedPropertyEnumerator<${interfaceName}>, v8::Integer::New(V8ClassIndex::NODE)") if $hasEnumerator;
    push(@implContent, ");\n");
}

sub GenerateImplementationNamedPropertyGetter
{
    my $dataNode = shift;
    my $namedPropertyGetter = shift;
    my $interfaceName = $dataNode->name;
    my $hasCustomGetter = $dataNode->extendedAttributes->{"HasOverridingNameGetter"} || $dataNode->extendedAttributes->{"CustomGetOwnPropertySlot"};

    # FIXME: Remove hard-coded HTMLOptionsCollection reference by changing HTMLOptionsCollection to not inherit
    # from HTMLCollection per W3C spec (http://www.w3.org/TR/2003/REC-DOM-Level-2-HTML-20030109/html.html#HTMLOptionsCollection).
    if ($interfaceName eq "HTMLOptionsCollection") {
        $interfaceName = "HTMLCollection";
        $hasCustomGetter = 1;
    }

    my $hasGetter = $dataNode->extendedAttributes->{"HasNameGetter"} || $hasCustomGetter || $namedPropertyGetter;
    if (!$hasGetter) {
        return;
    }

    if ($namedPropertyGetter && $namedPropertyGetter->type ne "Node" && !$namedPropertyGetter->extendedAttributes->{"Custom"} && !$hasCustomGetter) {
        $implIncludes{"V8Collection.h"} = 1;
        my $type = $namedPropertyGetter->type;
        my $classIndex = uc($type);
        push(@implContent, <<END);
  setCollectionNamedGetter<${interfaceName}, ${type}>(desc, V8ClassIndex::${classIndex});
END
        return;
    }

    my $hasSetter = $dataNode->extendedAttributes->{"DelegatingPutFunction"};
    # FIXME: Try to remove hard-coded HTMLDocument reference by aligning handling of document.all with JSC bindings.
    my $hasDeleter = $dataNode->extendedAttributes->{"CustomDeleteProperty"} || $interfaceName eq "HTMLDocument";
    my $hasEnumerator = $dataNode->extendedAttributes->{"CustomGetPropertyNames"};
    my $setOn = "Instance";

    # V8 has access-check callback API (see ObjectTemplate::SetAccessCheckCallbacks) and it's used on DOMWindow
    # instead of deleters or enumerators. In addition, the getter should be set on prototype template, to
    # get implementation straight out of the DOMWindow prototype regardless of what prototype is actually set
    # on the object.
    if ($interfaceName eq "DOMWindow") {
        $setOn = "Prototype";
        $hasDeleter = 0;
        $hasEnumerator = 0;
    }

    push(@implContent, "  desc->${setOn}Template()->SetNamedPropertyHandler(V8${interfaceName}::namedPropertyGetter, ");
    push(@implContent, $hasSetter ? "V8${interfaceName}::namedPropertySetter, " : "0, ");
    push(@implContent, "0, "); # NamedPropertyQuery -- not being used at the moment.
    push(@implContent, $hasDeleter ? "V8${interfaceName}::namedPropertyDeleter, " : "0, ");
    push(@implContent, $hasEnumerator ? "V8${interfaceName}::namedPropertyEnumerator" : "0");
    push(@implContent, ");\n");
}

sub GenerateImplementationCustomCall
{
    my $dataNode = shift;
    my $interfaceName = $dataNode->name;
    my $hasCustomCall = $dataNode->extendedAttributes->{"CustomCall"};

    # FIXME: Remove hard-coded HTMLOptionsCollection reference.
    if ($interfaceName eq "HTMLOptionsCollection") {
        $interfaceName = "HTMLCollection";
        $hasCustomCall = 1;
    }

    if ($hasCustomCall) {
        push(@implContent, "  desc->InstanceTemplate()->SetCallAsFunctionHandler(V8${interfaceName}::callAsFunctionCallback);\n");
    }
}

sub GenerateImplementationMasqueradesAsUndefined
{
    my $dataNode = shift;
    if ($dataNode->extendedAttributes->{"MasqueradesAsUndefined"})
    {
        push(@implContent, "  desc->InstanceTemplate()->MarkAsUndetectable();\n");
    }
}

sub GenerateImplementation
{
    my $object = shift;
    my $dataNode = shift;
    my $interfaceName = $dataNode->name;
    my $className = "V8$interfaceName";
    my $implClassName = $interfaceName;
    my $classIndex = uc($codeGenerator->StripModule($interfaceName));

    my $hasLegacyParent = $dataNode->extendedAttributes->{"LegacyParent"};
    my $conditionalString = GenerateConditionalString($dataNode);

    # - Add default header template
    @implContentHeader = split("\r", $headerTemplate);

    push(@implFixedHeader,
         "#include \"config.h\"\n" .
         "#include \"RuntimeEnabledFeatures.h\"\n" .
         "#include \"V8Proxy.h\"\n" .
         "#include \"V8Binding.h\"\n" .
         "#include \"V8BindingState.h\"\n" .
         "#include \"V8DOMWrapper.h\"\n" .
         "#include \"V8IsolatedContext.h\"\n\n" .
         "#undef LOG\n\n");

    push(@implFixedHeader, "\n#if ${conditionalString}\n\n") if $conditionalString;

    if ($className =~ /^V8SVGAnimated/) {
        AddIncludesForSVGAnimatedType($interfaceName);
    }

    $implIncludes{"${className}.h"} = 1;

    AddIncludesForType($interfaceName);

    push(@implContentDecls, "namespace WebCore {\n");
    push(@implContentDecls, "namespace ${interfaceName}Internal {\n\n");
    push(@implContentDecls, "template <typename T> void V8_USE(T) { }\n\n");

    my $hasConstructors = 0;
    # Generate property accessors for attributes.
    for ($index = 0; $index < @{$dataNode->attributes}; $index++) {
        $attribute = @{$dataNode->attributes}[$index];
        $attrName = $attribute->signature->name;
        $attrType = $attribute->signature->type;

        # Generate special code for the constructor attributes.
        if ($attrType =~ /Constructor$/) {
            if (!($attribute->signature->extendedAttributes->{"CustomGetter"} ||
                $attribute->signature->extendedAttributes->{"V8CustomGetter"})) {
                $hasConstructors = 1;
            }
            next;
        }

        if ($attrType eq "EventListener" && $interfaceName eq "DOMWindow") {
            $attribute->signature->extendedAttributes->{"v8OnProto"} = 1;
        }

        # Do not generate accessor if this is a custom attribute.  The
        # call will be forwarded to a hand-written accessor
        # implementation.
        if ($attribute->signature->extendedAttributes->{"Custom"} ||
            $attribute->signature->extendedAttributes->{"V8Custom"}) {
            next;
        }

        # Generate the accessor.
        if (!($attribute->signature->extendedAttributes->{"CustomGetter"} ||
            $attribute->signature->extendedAttributes->{"V8CustomGetter"})) {
            GenerateNormalAttrGetter($attribute, $dataNode, $implClassName, $interfaceName);
        }
        if (!($attribute->signature->extendedAttributes->{"CustomSetter"} ||
            $attribute->signature->extendedAttributes->{"V8CustomSetter"})) {
            if ($attribute->signature->extendedAttributes->{"Replaceable"}) {
                $dataNode->extendedAttributes->{"ExtendsDOMGlobalObject"} || die "Replaceable attribute can only be used in interface that defines ExtendsDOMGlobalObject attribute!";
                # GenerateReplaceableAttrSetter($implClassName);
            } elsif ($attribute->type !~ /^readonly/ && !$attribute->signature->extendedAttributes->{"V8ReadOnly"}) {
                GenerateNormalAttrSetter($attribute, $dataNode, $implClassName, $interfaceName);
            }
        }
    }

    if ($hasConstructors) {
        GenerateConstructorGetter($implClassName, $classIndex);
    }

    my $indexer;
    my $namedPropertyGetter;
    # Generate methods for functions.
    foreach my $function (@{$dataNode->functions}) {
        # hack for addEventListener/RemoveEventListener
        # FIXME: avoid naming conflict
        if (!($function->signature->extendedAttributes->{"Custom"} || $function->signature->extendedAttributes->{"V8Custom"})) {
            GenerateFunctionCallback($function, $dataNode, $classIndex, $implClassName);
        }

        if ($function->signature->name eq "item") {
            $indexer = $function->signature;
        }

        if ($function->signature->name eq "namedItem") {
            $namedPropertyGetter = $function->signature;
        }

        # If the function does not need domain security check, we need to
        # generate an access getter that returns different function objects
        # for different calling context.
        if (($dataNode->extendedAttributes->{"CheckDomainSecurity"} || ($interfaceName eq "DOMWindow")) && $function->signature->extendedAttributes->{"DoNotCheckDomainSecurity"}) {
            GenerateDomainSafeFunctionGetter($function, $dataNode, $implClassName);
        }
    }

    # Attributes
    my $attributes = $dataNode->attributes;

    # For the DOMWindow interface we partition the attributes into the
    # ones that disallows shadowing and the rest.
    my @disallowsShadowing;
    # Also separate out attributes that are enabled at runtime so we can process them specially.
    my @enabledAtRuntime;
    my @normal;
    foreach my $attribute (@$attributes) {

        if ($interfaceName eq "DOMWindow" && $attribute->signature->extendedAttributes->{"V8DisallowShadowing"}) {
            push(@disallowsShadowing, $attribute);
        } elsif ($attribute->signature->extendedAttributes->{"EnabledAtRuntime"}) {
            push(@enabledAtRuntime, $attribute);
        } else {
            push(@normal, $attribute);
        }
    }
    $attributes = \@normal;
    # Put the attributes that disallow shadowing on the shadow object.
    if (@disallowsShadowing) {
        push(@implContent, "static const BatchedAttribute shadow_attrs[] = {\n");
        GenerateBatchedAttributeData($dataNode, \@disallowsShadowing);
        push(@implContent, "};\n");
    }

    my $has_attributes = 0;
    if (@$attributes) {
        $has_attributes = 1;
        push(@implContent, "static const BatchedAttribute ${interfaceName}_attrs[] = {\n");
        GenerateBatchedAttributeData($dataNode, $attributes);
        push(@implContent, "};\n");
    }

    # Setup table of standard callback functions
    $num_callbacks = 0;
    $has_callbacks = 0;
    foreach my $function (@{$dataNode->functions}) {
        my $attrExt = $function->signature->extendedAttributes;
        # Don't put any nonstandard functions into this table:
        if ($attrExt->{"V8OnInstance"}) {
            next;
        }
        if ($attrExt->{"EnabledAtRuntime"} || RequiresCustomSignature($function) || $attrExt->{"V8DoNotCheckSignature"}) {
            next;
        }
        if ($attrExt->{"DoNotCheckDomainSecurity"} &&
            ($dataNode->extendedAttributes->{"CheckDomainSecurity"} || $interfaceName eq "DOMWindow")) {
            next;
        }
        if ($attrExt->{"DontEnum"} || $attrExt->{"V8ReadOnly"}) {
            next;
        }
        if (!$has_callbacks) {
            $has_callbacks = 1;
            push(@implContent, "static const BatchedCallback ${interfaceName}_callbacks[] = {\n");
        }
        my $name = $function->signature->name;
        my $callback = GetFunctionTemplateCallbackName($function, $dataNode);
        push(@implContent, <<END);
  {"$name", $callback},
END
        $num_callbacks++;
    }
    push(@implContent, "};\n")  if $has_callbacks;

    # Setup constants
    my $has_constants = 0;
    if (@{$dataNode->constants}) {
        $has_constants = 1;
        push(@implContent, "static const BatchedConstant ${interfaceName}_consts[] = {\n");
    }
    foreach my $constant (@{$dataNode->constants}) {
        my $name = $constant->name;
        my $value = $constant->value;
        # FIXME: we need the static_cast here only because of one constant, NodeFilter.idl
        # defines "const unsigned long SHOW_ALL = 0xFFFFFFFF".  It would be better if we
        # handled this here, and converted it to a -1 constant in the c++ output.
        push(@implContent, <<END);
  { "${name}", static_cast<signed int>($value) },
END
    }
    if ($has_constants) {
        push(@implContent, "};\n");
    }

    push(@implContentDecls, "} // namespace ${interfaceName}Internal\n\n");

    # In namespace WebCore, add generated implementation for 'CanBeConstructed'.
    if ($dataNode->extendedAttributes->{"CanBeConstructed"} && !$dataNode->extendedAttributes->{"CustomConstructor"}) {
        push(@implContent, <<END);
 v8::Handle<v8::Value> ${className}::constructorCallback(const v8::Arguments& args)
  {
    INC_STATS("DOM.${interfaceName}.Contructor");
    return V8Proxy::constructDOMObject<V8ClassIndex::${classIndex}, $interfaceName>(args);
  }
END
   }

    my $access_check = "";
    if ($dataNode->extendedAttributes->{"CheckDomainSecurity"} && !($interfaceName eq "DOMWindow")) {
        $access_check = "instance->SetAccessCheckCallbacks(V8${interfaceName}::namedSecurityCheck, V8${interfaceName}::indexedSecurityCheck, v8::Integer::New(V8ClassIndex::ToInt(V8ClassIndex::${classIndex})));";
    }

    # For the DOMWindow interface, generate the shadow object template
    # configuration method.
    if ($implClassName eq "DOMWindow") {
        push(@implContent, <<END);
static v8::Persistent<v8::ObjectTemplate> ConfigureShadowObjectTemplate(v8::Persistent<v8::ObjectTemplate> templ) {
  batchConfigureAttributes(templ,
                           v8::Handle<v8::ObjectTemplate>(),
                           shadow_attrs,
                           sizeof(shadow_attrs)/sizeof(*shadow_attrs));

  // Install a security handler with V8.
  templ->SetAccessCheckCallbacks(V8DOMWindow::namedSecurityCheck, V8DOMWindow::indexedSecurityCheck, v8::Integer::New(V8ClassIndex::DOMWINDOW));
  templ->SetInternalFieldCount(V8DOMWindow::internalFieldCount);
  return templ;
}
END
    }

    # find the super descriptor
    my $parentClassTemplate = "";
    foreach (@{$dataNode->parents}) {
        my $parent = $codeGenerator->StripModule($_);
        if ($parent eq "EventTarget") { next; }
        $implIncludes{"V8${parent}.h"} = 1;
        $parentClassTemplate = "V8" . $parent . "::GetTemplate()";
        last;
    }
    if (!$parentClassTemplate) {
        $parentClassTemplate = "v8::Persistent<v8::FunctionTemplate>()";
    }

    # Generate the template configuration method
    push(@implContent,  <<END);
static v8::Persistent<v8::FunctionTemplate> Configure${className}Template(v8::Persistent<v8::FunctionTemplate> desc) {
  v8::Local<v8::Signature> default_signature = configureTemplate(desc, \"${interfaceName}\",
      $parentClassTemplate, V8${interfaceName}::internalFieldCount,
END
    # Set up our attributes if we have them
    if ($has_attributes) {
        push(@implContent, <<END);
      ${interfaceName}_attrs, sizeof(${interfaceName}_attrs)/sizeof(*${interfaceName}_attrs),
END
    } else {
        push(@implContent, <<END);
      NULL, 0,
END
    }

    if ($has_callbacks) {
        push(@implContent, <<END);
      ${interfaceName}_callbacks, sizeof(${interfaceName}_callbacks)/sizeof(*${interfaceName}_callbacks));
END
    } else {
        push(@implContent, <<END);
      NULL, 0);
END
    }

    if ($dataNode->extendedAttributes->{"CustomConstructor"} || $dataNode->extendedAttributes->{"CanBeConstructed"}) {
        push(@implContent, <<END);
      desc->SetCallHandler(V8${interfaceName}::constructorCallback);
END
    }

    if ($access_check or @enabledAtRuntime or @{$dataNode->functions} or $has_constants) {
        push(@implContent,  <<END);
  v8::Local<v8::ObjectTemplate> instance = desc->InstanceTemplate();
  v8::Local<v8::ObjectTemplate> proto = desc->PrototypeTemplate();
END
    }

    push(@implContent,  "  $access_check\n");

    # Setup the enable-at-runtime attrs if we have them
    foreach my $runtime_attr (@enabledAtRuntime) {
        # A function named RuntimeEnabledFeatures::{methodName}Enabled() need to be written by hand.
        $enable_function = "RuntimeEnabledFeatures::" . $codeGenerator->WK_lcfirst($runtime_attr->signature->name) . "Enabled";
        my $conditionalString = GenerateConditionalString($runtime_attr->signature);
        push(@implContent, "\n#if ${conditionalString}\n") if $conditionalString;
        push(@implContent, "    if (${enable_function}()) {\n");
        push(@implContent, "        static const BatchedAttribute attrData =\\\n");
        GenerateSingleBatchedAttribute($interfaceName, $runtime_attr, ";", "    ");
        push(@implContent, <<END);
        configureAttribute(instance, proto, attrData);
    }
END
        push(@implContent, "\n#endif // ${conditionalString}\n") if $conditionalString;
    }

    GenerateImplementationIndexer($dataNode, $indexer);
    GenerateImplementationNamedPropertyGetter($dataNode, $namedPropertyGetter);
    GenerateImplementationCustomCall($dataNode);
    GenerateImplementationMasqueradesAsUndefined($dataNode);

    # Define our functions with Set() or SetAccessor()
    $total_functions = 0;
    foreach my $function (@{$dataNode->functions}) {
        $total_functions++;
        my $attrExt = $function->signature->extendedAttributes;
        my $name = $function->signature->name;

        my $property_attributes = "v8::DontDelete";
        if ($attrExt->{"DontEnum"}) {
            $property_attributes .= "|v8::DontEnum";
        }
        if ($attrExt->{"V8ReadOnly"}) {
            $property_attributes .= "|v8::ReadOnly";
        }

        my $commentInfo = "Function '$name' (ExtAttr: '" . join(' ', keys(%{$attrExt})) . "')";

        my $template = "proto";
        if ($attrExt->{"V8OnInstance"}) {
            $template = "instance";
        }

        my $conditional = "";
        if ($attrExt->{"EnabledAtRuntime"}) {
            # Only call Set()/SetAccessor() if this method should be enabled
            $enable_function = "RuntimeEnabledFeatures::" . $codeGenerator->WK_lcfirst($function->signature->name) . "Enabled";
            $conditional = "if (${enable_function}())\n";
        }

        if ($attrExt->{"DoNotCheckDomainSecurity"} &&
            ($dataNode->extendedAttributes->{"CheckDomainSecurity"} || $interfaceName eq "DOMWindow")) {
            # Mark the accessor as ReadOnly and set it on the proto object so
            # it can be shadowed. This is really a hack to make it work.
            # There are several sceneria to call into the accessor:
            #   1) from the same domain: "window.open":
            #      the accessor finds the DOM wrapper in the proto chain;
            #   2) from the same domain: "window.__proto__.open":
            #      the accessor will NOT find a DOM wrapper in the prototype chain
            #   3) from another domain: "window.open":
            #      the access find the DOM wrapper in the prototype chain
            #   "window.__proto__.open" from another domain will fail when
            #   accessing '__proto__'
            #
            # The solution is very hacky and fragile, it really needs to be replaced
            # by a better solution.
            $property_attributes .= "|v8::ReadOnly";
            push(@implContent, <<END);

  // $commentInfo
  $conditional $template->SetAccessor(
      v8::String::New("$name"),
      ${interfaceName}Internal::${name}AttrGetter,
      0,
      v8::Handle<v8::Value>(),
      v8::ALL_CAN_READ,
      static_cast<v8::PropertyAttribute>($property_attributes));
END
          $num_callbacks++;
          next;
      }

      my $signature = "default_signature";
      if ($attrExt->{"V8DoNotCheckSignature"}){
          $signature = "v8::Local<v8::Signature>()";
      }

      if (RequiresCustomSignature($function)) {
          $signature = "${name}_signature";
          push(@implContent, "\n  // Custom Signature '$name'\n", CreateCustomSignature($function));
      }

      # Normal function call is a template
      my $callback = GetFunctionTemplateCallbackName($function, $dataNode);

      if ($property_attributes eq "v8::DontDelete") {
          $property_attributes = "";
      } else {
          $property_attributes = ", static_cast<v8::PropertyAttribute>($property_attributes)";
      }

      if ($template eq "proto" && $conditional eq "" && $signature eq "default_signature" && $property_attributes eq "") {
          # Standard type of callback, already created in the batch, so skip it here.
          next;
      }

      push(@implContent, <<END);
  ${conditional}$template->Set(v8::String::New("$name"), v8::FunctionTemplate::New($callback, v8::Handle<v8::Value>(), ${signature})$property_attributes);
END
      $num_callbacks++;
    }

    die "Wrong number of callbacks generated for $interfaceName ($num_callbacks, should be $total_functions)" if $num_callbacks != $total_functions;

    if ($has_constants) {
        push(@implContent, <<END);
  batchConfigureConstants(desc, proto, ${interfaceName}_consts, sizeof(${interfaceName}_consts)/sizeof(*${interfaceName}_consts));
END
    }

    # Special cases
    if ($interfaceName eq "DOMWindow") {
        push(@implContent, <<END);

  proto->SetInternalFieldCount(V8DOMWindow::internalFieldCount);
  desc->SetHiddenPrototype(true);
  instance->SetInternalFieldCount(V8DOMWindow::internalFieldCount);
  // Set access check callbacks, but turned off initially.
  // When a context is detached from a frame, turn on the access check.
  // Turning on checks also invalidates inline caches of the object.
  instance->SetAccessCheckCallbacks(V8DOMWindow::namedSecurityCheck, V8DOMWindow::indexedSecurityCheck, v8::Integer::New(V8ClassIndex::DOMWINDOW), false);
END
    }
    if ($interfaceName eq "Location") {
        push(@implContent, <<END);

  // For security reasons, these functions are on the instance instead
  // of on the prototype object to insure that they cannot be overwritten.
  instance->SetAccessor(v8::String::New("reload"), V8Location::reloadAccessorGetter, 0, v8::Handle<v8::Value>(), v8::ALL_CAN_READ, static_cast<v8::PropertyAttribute>(v8::DontDelete | v8::ReadOnly));
  instance->SetAccessor(v8::String::New("replace"), V8Location::replaceAccessorGetter, 0, v8::Handle<v8::Value>(), v8::ALL_CAN_READ, static_cast<v8::PropertyAttribute>(v8::DontDelete | v8::ReadOnly));
  instance->SetAccessor(v8::String::New("assign"), V8Location::assignAccessorGetter, 0, v8::Handle<v8::Value>(), v8::ALL_CAN_READ, static_cast<v8::PropertyAttribute>(v8::DontDelete | v8::ReadOnly));
END
    }

    my $nativeType = GetNativeTypeForConversions($interfaceName);
    if ($dataNode->extendedAttributes->{"PODType"}) {
        $nativeType = "V8SVGPODTypeWrapper<${nativeType}>";
    }
    push(@implContent, <<END);

  // Custom toString template
  desc->Set(getToStringName(), getToStringTemplate());
  return desc;
}

v8::Persistent<v8::FunctionTemplate> ${className}::GetRawTemplate() {
  static v8::Persistent<v8::FunctionTemplate> ${className}_raw_cache_ = createRawTemplate();
  return ${className}_raw_cache_;
}

v8::Persistent<v8::FunctionTemplate> ${className}::GetTemplate() {
  static v8::Persistent<v8::FunctionTemplate> ${className}_cache_ = Configure${className}Template(GetRawTemplate());
  return ${className}_cache_;
}

${nativeType}* ${className}::toNative(v8::Handle<v8::Object> object) {
  return reinterpret_cast<${nativeType}*>(object->GetPointerFromInternalField(v8DOMWrapperObjectIndex));
}

bool ${className}::HasInstance(v8::Handle<v8::Value> value) {
  return GetRawTemplate()->HasInstance(value);
}

END

    if ($implClassName eq "DOMWindow") {
        push(@implContent, <<END);
v8::Persistent<v8::ObjectTemplate> V8DOMWindow::GetShadowObjectTemplate() {
  static v8::Persistent<v8::ObjectTemplate> V8DOMWindowShadowObject_cache_;
  if (V8DOMWindowShadowObject_cache_.IsEmpty()) {
    V8DOMWindowShadowObject_cache_ = v8::Persistent<v8::ObjectTemplate>::New(v8::ObjectTemplate::New());
    ConfigureShadowObjectTemplate(V8DOMWindowShadowObject_cache_);
  }
  return V8DOMWindowShadowObject_cache_;
}
END
    }

    GenerateToV8Converters($dataNode, $interfaceName, $className, $nativeType);

    push(@implContent, <<END);
} // namespace WebCore
END

    push(@implContent, "\n#endif // ${conditionalString}\n") if $conditionalString;
}

sub GenerateToV8Converters
{
    my $dataNode = shift;
    my $interfaceName = shift;
    my $className = shift;
    my $nativeType = shift;

    my $wrapperType = "V8ClassIndex::" . uc($interfaceName);
    my $domMapFunction = GetDomMapFunction($dataNode, $interfaceName);
    my $forceNewObjectInput = IsDOMNodeType($interfaceName) ? ", bool forceNewObject" : "";
    my $forceNewObjectCall = IsDOMNodeType($interfaceName) ? ", forceNewObject" : "";

    push(@implContent, <<END);

v8::Handle<v8::Object> ${className}::wrap(${nativeType}* impl${forceNewObjectInput}) {
  v8::Handle<v8::Object> wrapper;
  V8Proxy* proxy = 0;
END

    if (IsNodeSubType($dataNode)) {
        push(@implContent, <<END);
  if (impl->document()) {
    proxy = V8Proxy::retrieve(impl->document()->frame());
    if (proxy && static_cast<Node*>(impl->document()) == static_cast<Node*>(impl))
      proxy->windowShell()->initContextIfNeeded();
  }

END
    }

    if ($domMapFunction) {
        push(@implContent, "  if (!forceNewObject) {\n") if IsDOMNodeType($interfaceName);
        if (IsNodeSubType($dataNode)) {
            push(@implContent, "  wrapper = V8DOMWrapper::getWrapper(impl);\n");
        } else {
            push(@implContent, "  wrapper = ${domMapFunction}.get(impl);\n");
        }
        push(@implContent, <<END);
  if (!wrapper.IsEmpty())
    return wrapper;
END
        push(@implContent, "  }\n") if IsDOMNodeType($interfaceName);
    }
    if (IsNodeSubType($dataNode)) {
        push(@implContent, <<END);

  v8::Handle<v8::Context> context;
  if (proxy)
    context = proxy->context();

  // Enter the node's context and create the wrapper in that context.
  if (!context.IsEmpty())
    context->Enter();
END
    }

    push(@implContent, <<END);
  wrapper = V8DOMWrapper::instantiateV8Object(proxy, ${wrapperType}, impl);
END

    if (IsNodeSubType($dataNode)) {
        push(@implContent, <<END);
  // Exit the node's context if it was entered.
  if (!context.IsEmpty())
    context->Exit();
END
    }

    push(@implContent, <<END);
  if (wrapper.IsEmpty())
    return wrapper;
END
    push(@implContent, "\n  impl->ref();\n") if IsRefPtrType($interfaceName);

    if ($domMapFunction) {
        push(@implContent, <<END);
  ${domMapFunction}.set(impl, v8::Persistent<v8::Object>::New(wrapper));
END
    }

    push(@implContent, <<END);
  return wrapper;
}
END

    if (IsRefPtrType($interfaceName)) {
        push(@implContent, <<END);

v8::Handle<v8::Value> toV8(PassRefPtr<${nativeType} > impl${forceNewObjectInput}) {
  return toV8(impl.get()${forceNewObjectCall});
}
END
    }

    if (!HasCustomToV8Implementation($dataNode, $interfaceName)) {
        push(@implContent, <<END);

v8::Handle<v8::Value> toV8(${nativeType}* impl${forceNewObjectInput}) {
  if (!impl)
    return v8::Null();
  return ${className}::wrap(impl${forceNewObjectCall});
}
END
    }
}

sub HasCustomToV8Implementation {
    # FIXME: This subroutine is lame. Probably should be an .idl attribute (CustomToV8)?
    $dataNode = shift;
    $interfaceName = shift;

    # We generate a custom converter (but JSC doesn't) for the following:
    return 1 if $interfaceName eq "BarInfo";
    return 1 if $interfaceName eq "CSSStyleSheet";
    return 1 if $interfaceName eq "CanvasPixelArray";
    return 1 if $interfaceName eq "DOMSelection";
    return 1 if $interfaceName eq "DOMWindow";
    return 1 if $interfaceName eq "Element";
    return 1 if $interfaceName eq "Location";
    return 1 if $interfaceName eq "HTMLDocument";
    return 1 if $interfaceName eq "HTMLElement";
    return 1 if $interfaceName eq "History";
    return 1 if $interfaceName eq "NamedNodeMap";
    return 1 if $interfaceName eq "Navigator";
    return 1 if $interfaceName eq "SVGDocument";
    return 1 if $interfaceName eq "SVGElement";
    return 1 if $interfaceName eq "Screen";
    return 1 if $interfaceName eq "WorkerContext";
    # We don't generate a custom converter (but JSC does) for the following:
    return 0 if $interfaceName eq "AbstractWorker";
    return 0 if $interfaceName eq "CanvasRenderingContext";
    return 0 if $interfaceName eq "ImageData";
    return 0 if $interfaceName eq "SVGElementInstance";

    # For everything else, do what JSC does.
    return $dataNode->extendedAttributes->{"CustomToJS"};
}

sub GetDomMapFunction
{
    my $dataNode = shift;
    my $type = shift;
    return "getDOMSVGElementInstanceMap()" if $type eq "SVGElementInstance";
    return "getDOMNodeMap()" if IsNodeSubType($dataNode);
    # Only use getDOMSVGObjectWithContextMap() for non-node svg objects
    return "getDOMSVGObjectWithContextMap()" if $type =~ /SVG/;
    return "" if $type eq "DOMImplementation";
    return "getActiveDOMObjectMap()" if IsActiveDomType($type);
    return "getDOMObjectMap()";
}

sub IsActiveDomType
{
    # FIXME: Consider making this an .idl attribute.
    my $type = shift;
    return 1 if $type eq "MessagePort";
    return 1 if $type eq "XMLHttpRequest";
    return 1 if $type eq "WebSocket";
    return 1 if $type eq "Worker";
    return 1 if $type eq "SharedWorker";
    return 0;
}

sub GetNativeTypeForConversions
{
    my $type = shift;
    return "FloatRect" if $type eq "SVGRect";
    return "FloatPoint" if $type eq "SVGPoint";
    return "AffineTransform" if $type eq "SVGMatrix";
    return "float" if $type eq "SVGNumber";
    return $type;
}

sub GenerateFunctionCallString()
{
    my $function = shift;
    my $numberOfParameters = shift;
    my $indent = shift;
    my $implClassName = shift;

    my $name = $function->signature->name;
    my $isPodType = IsPodType($implClassName);
    my $returnType = GetTypeFromSignature($function->signature);
    my $returnsPodType = IsPodType($returnType);
    my $nativeReturnType = GetNativeType($returnType, 0);
    my $result = "";

    # Special case: SVG matrix transform methods should not mutate
    # the matrix but return a copy
    my $copyFirst = 0;
    if ($implClassName eq "SVGMatrix" && $function->signature->type eq "SVGMatrix") {
        $copyFirst = 1;
    }

    if ($function->signature->extendedAttributes->{"v8implname"}) {
        $name = $function->signature->extendedAttributes->{"v8implname"};
    }

    if ($function->signature->extendedAttributes->{"ImplementationFunction"}) {
        $name = $function->signature->extendedAttributes->{"ImplementationFunction"};
    }

    my $functionString = "imp->${name}(";

    if ($copyFirst) {
        $functionString = "result.${name}(";
    }

    my $returnsListItemPodType = 0;
    # SVG lists functions that return POD types require special handling
    if (IsSVGListTypeNeedingSpecialHandling($implClassName) && IsSVGListMethod($name) && $returnsPodType) {
        $returnsListItemPodType = 1;
        $result .= $indent . "SVGList<RefPtr<SVGPODListItem<$nativeReturnType> > >* listImp = imp;\n";
        $functionString = "listImp->${name}(";
    }

    my $first = 1;
    my $index = 0;

    foreach my $parameter (@{$function->parameters}) {
        if ($index eq $numberOfParameters) {
            last;
        }
        if ($first) { $first = 0; }
        else { $functionString .= ", "; }
        my $paramName = $parameter->name;
        my $paramType = $parameter->type;

        # This is a bit of a hack... we need to convert parameters to methods on SVG lists
        # of POD types which are items in the list to appropriate SVGList<> instances
        if ($returnsListItemPodType && $paramType . "List" eq $implClassName) {
            $paramName = "SVGPODListItem<" . GetNativeType($paramType, 1) . ">::copy($paramName)";
        }

        if ($parameter->type eq "NodeFilter" || $parameter->type eq "XPathNSResolver") {
            $functionString .= "$paramName.get()";
        } else {
            $functionString .= $paramName;
        }
        $index++;
    }

    if ($function->signature->extendedAttributes->{"CustomArgumentHandling"}) {
        $functionString .= ", " if not $first;
        $functionString .= "callStack.get()";
        if ($first) { $first = 0; }
    }

    if ($function->signature->extendedAttributes->{"NeedsUserGestureCheck"}) {
        $functionString .= ", " if not $first;
        # FIXME: We need to pass DOMWrapperWorld as a parameter.
        # See http://trac.webkit.org/changeset/54182
        $functionString .= "processingUserGesture()";
        if ($first) { $first = 0; }
    }

    if (@{$function->raisesExceptions}) {
        $functionString .= ", " if not $first;
        $functionString .= "ec";
    }
    $functionString .= ")";

    my $return = "result";
    my $returnIsRef = IsRefPtrType($returnType);

    if ($returnType eq "void") {
        $result .= $indent . "$functionString;\n";
    } elsif ($copyFirst) {
        $result .=
            $indent . GetNativeType($returnType, 0) . " result = *imp;\n" .
            $indent . "$functionString;\n";
    } elsif ($returnsListItemPodType) {
        $result .= $indent . "RefPtr<SVGPODListItem<$nativeReturnType> > result = $functionString;\n";
    } elsif (@{$function->raisesExceptions} or $returnsPodType or $isPodType or IsSVGTypeNeedingContextParameter($returnType)) {
        $result .= $indent . $nativeReturnType . " result = $functionString;\n";
    } else {
        # Can inline the function call into the return statement to avoid overhead of using a Ref<> temporary
        $return = $functionString;
        $returnIsRef = 0;
    }

    if (@{$function->raisesExceptions}) {
        $result .= $indent . "if (UNLIKELY(ec)) goto fail;\n";
    }

    # If the return type is a POD type, separate out the wrapper generation
    if ($returnsListItemPodType) {
        $result .= $indent . "RefPtr<V8SVGPODTypeWrapper<" . $nativeReturnType . "> > wrapper = ";
        $result .= "V8SVGPODTypeWrapperCreatorForList<" . $nativeReturnType . ">::create($return, imp->associatedAttributeName());\n";
        $return = "wrapper";
    } elsif ($returnsPodType) {
        $result .= $indent . "RefPtr<V8SVGPODTypeWrapper<" . $nativeReturnType . "> > wrapper = ";
        $result .= GenerateSVGStaticPodTypeWrapper($returnType, $return) . ";\n";
        $return = "wrapper";
    }

    my $generatedSVGContextRetrieval = 0;
    # If the return type needs an SVG context, output it
    if (IsSVGTypeNeedingContextParameter($returnType)) {
        $result .= GenerateSVGContextAssignment($implClassName, $return . ".get()", $indent);
        $generatedSVGContextRetrieval = 1;
    }

    if (IsSVGTypeNeedingContextParameter($implClassName) && $implClassName =~ /List$/ && IsSVGListMutator($name)) {
        if (!$generatedSVGContextRetrieval) {
            $result .= GenerateSVGContextRetrieval($implClassName, $indent);
            $generatedSVGContextRetrieval = 1;
        }

        $result .= $indent . "context->svgAttributeChanged(imp->associatedAttributeName());\n";
        $implIncludes{"SVGElement.h"} = 1;
    }

    # If the implementing class is a POD type, commit changes
    if ($isPodType) {
        if (!$generatedSVGContextRetrieval) {
            $result .= GenerateSVGContextRetrieval($implClassName, $indent);
            $generatedSVGContextRetrieval = 1;
        }

        $result .= $indent . "imp_wrapper->commitChange(imp_instance, context);\n";
    }

    if ($returnsPodType) {
        $implIncludes{"V8${returnType}.h"} = 1;
        $result .= $indent . "return toV8(wrapper.release());\n";
    } else {
        $return .= ".release()" if ($returnIsRef);
        $result .= $indent . ReturnNativeToJSValue($function->signature, $return, $indent) . ";\n";
    }

    return $result;
}


sub GetTypeFromSignature
{
    my $signature = shift;

    return $codeGenerator->StripModule($signature->type);
}


sub GetNativeTypeFromSignature
{
    my $signature = shift;
    my $parameterIndex = shift;

    my $type = GetTypeFromSignature($signature);

    if ($type eq "unsigned long" and $signature->extendedAttributes->{"IsIndex"}) {
        # Special-case index arguments because we need to check that they aren't < 0.
        return "int";
    }

    $type = GetNativeType($type, $parameterIndex >= 0 ? 1 : 0);

    if ($parameterIndex >= 0 && $type eq "V8Parameter") {
        my $mode = "";
        if ($signature->extendedAttributes->{"ConvertUndefinedOrNullToNullString"}) {
            $mode = "WithUndefinedOrNullCheck";
        } elsif ($signature->extendedAttributes->{"ConvertNullToNullString"}) {
            $mode = "WithNullCheck";
        }
        $type .= "<$mode>";
    }

    return $type;
}

sub IsRefPtrType
{
    my $type = shift;

    return 0 if $type eq "boolean";
    return 0 if $type eq "float";
    return 0 if $type eq "int";
    return 0 if $type eq "Date";
    return 0 if $type eq "DOMString";
    return 0 if $type eq "double";
    return 0 if $type eq "short";
    return 0 if $type eq "long";
    return 0 if $type eq "unsigned";
    return 0 if $type eq "unsigned long";
    return 0 if $type eq "unsigned short";
    return 0 if $type eq "SVGAnimatedPoints";

    return 1;
}

sub GetNativeType
{
    my $type = shift;
    my $isParameter = shift;

    if ($type eq "float" or $type eq "double") {
        return $type;
    }

    return "V8Parameter" if ($type eq "DOMString" or $type eq "DOMUserData") and $isParameter;
    return "int" if $type eq "int";
    return "int" if $type eq "short" or $type eq "unsigned short";
    return "unsigned" if $type eq "unsigned long";
    return "int" if $type eq "long";
    return "long long" if $type eq "long long";
    return "unsigned long long" if $type eq "unsigned long long";
    return "bool" if $type eq "boolean";
    return "String" if $type eq "DOMString";
    return "Range::CompareHow" if $type eq "CompareHow";
    return "FloatRect" if $type eq "SVGRect";
    return "FloatPoint" if $type eq "SVGPoint";
    return "AffineTransform" if $type eq "SVGMatrix";
    return "SVGTransform" if $type eq "SVGTransform";
    return "SVGLength" if $type eq "SVGLength";
    return "SVGAngle" if $type eq "SVGAngle";
    return "float" if $type eq "SVGNumber";
    return "SVGPreserveAspectRatio" if $type eq "SVGPreserveAspectRatio";
    return "SVGPaint::SVGPaintType" if $type eq "SVGPaintType";
    return "DOMTimeStamp" if $type eq "DOMTimeStamp";
    return "unsigned" if $type eq "unsigned int";
    return "Node*" if $type eq "EventTarget" and $isParameter;
    return "double" if $type eq "Date";

    return "String" if $type eq "DOMUserData";  # FIXME: Temporary hack?

    # temporary hack
    return "RefPtr<NodeFilter>" if $type eq "NodeFilter";

    # necessary as resolvers could be constructed on fly.
    return "RefPtr<XPathNSResolver>" if $type eq "XPathNSResolver";

    return "RefPtr<${type}>" if IsRefPtrType($type) and not $isParameter;

    # Default, assume native type is a pointer with same type name as idl type
    return "${type}*";
}


my %typeCanFailConversion = (
    "Attr" => 1,
    "WebGLArray" => 0,
    "WebGLBuffer" => 0,
    "WebGLByteArray" => 0,
    "WebGLUnsignedByteArray" => 0,
    "WebGLContextAttributes" => 0,
    "WebGLFloatArray" => 0,
    "WebGLFramebuffer" => 0,
    "CanvasGradient" => 0,
    "WebGLIntArray" => 0,
    "CanvasPixelArray" => 0,
    "WebGLProgram" => 0,
    "WebGLRenderbuffer" => 0,
    "WebGLShader" => 0,
    "WebGLShortArray" => 0,
    "WebGLTexture" => 0,
    "WebGLUniformLocation" => 0,
    "CompareHow" => 0,
    "DataGridColumn" => 0,
    "DOMString" => 0,
    "DOMWindow" => 0,
    "DocumentType" => 0,
    "Element" => 0,
    "Event" => 0,
    "EventListener" => 0,
    "EventTarget" => 0,
    "HTMLCanvasElement" => 0,
    "HTMLElement" => 0,
    "HTMLImageElement" => 0,
    "HTMLOptionElement" => 0,
    "HTMLVideoElement" => 0,
    "Node" => 0,
    "NodeFilter" => 0,
    "MessagePort" => 0,
    "NSResolver" => 0,
    "Range" => 0,
    "SQLResultSet" => 0,
    "Storage" => 0,
    "SVGAngle" => 1,
    "SVGElement" => 0,
    "SVGLength" => 1,
    "SVGMatrix" => 1,
    "SVGNumber" => 0,
    "SVGPaintType" => 0,
    "SVGPathSeg" => 0,
    "SVGPoint" => 1,
    "SVGPreserveAspectRatio" => 1,
    "SVGRect" => 1,
    "SVGTransform" => 1,
    "TouchList" => 0,
    "VoidCallback" => 1,
    "WebKitCSSMatrix" => 0,
    "WebKitPoint" => 0,
    "XPathEvaluator" => 0,
    "XPathNSResolver" => 0,
    "XPathResult" => 0,
    "boolean" => 0,
    "double" => 0,
    "float" => 0,
    "long" => 0,
    "unsigned long" => 0,
    "unsigned short" => 0,
    "long long" => 0,
    "unsigned long long" => 0
);


sub TranslateParameter
{
    my $signature = shift;

    # The IDL uses some pseudo-types which don't really exist.
    if ($signature->type eq "TimeoutHandler") {
      $signature->type("DOMString");
    }
}

sub BasicTypeCanFailConversion
{
    my $signature = shift;
    my $type = GetTypeFromSignature($signature);

    return 1 if $type eq "SVGAngle";
    return 1 if $type eq "SVGLength";
    return 1 if $type eq "SVGMatrix";
    return 1 if $type eq "SVGPoint";
    return 1 if $type eq "SVGPreserveAspectRatio";
    return 1 if $type eq "SVGRect";
    return 1 if $type eq "SVGTransform";
    return 0;
}

sub TypeCanFailConversion
{
    my $signature = shift;

    my $type = GetTypeFromSignature($signature);

    $implIncludes{"ExceptionCode.h"} = 1 if $type eq "Attr";

    return $typeCanFailConversion{$type} if exists $typeCanFailConversion{$type};

    die "Don't know whether a JS value can fail conversion to type $type.";
}

sub JSValueToNative
{
    my $signature = shift;
    my $value = shift;
    my $okParam = shift;
    my $maybeOkParam = $okParam ? ", ${okParam}" : "";

    my $type = GetTypeFromSignature($signature);

    return "$value" if $type eq "JSObject";
    return "$value->BooleanValue()" if $type eq "boolean";
    return "static_cast<$type>($value->NumberValue())" if $type eq "float" or $type eq "double";
    return "$value->NumberValue()" if $type eq "SVGNumber";

    return "toInt32($value${maybeOkParam})" if $type eq "unsigned long" or $type eq "unsigned short" or $type eq "long";
    return "toInt64($value)" if $type eq "unsigned long long" or $type eq "long long";
    return "static_cast<Range::CompareHow>($value->Int32Value())" if $type eq "CompareHow";
    return "static_cast<SVGPaint::SVGPaintType>($value->ToInt32()->Int32Value())" if $type eq "SVGPaintType";
    return "toWebCoreDate($value)" if $type eq "Date";

    if ($type eq "DOMString" or $type eq "DOMUserData") {
        return $value;
    }

    if ($type eq "SerializedScriptValue") {
        $implIncludes{"SerializedScriptValue.h"} = 1;
        return "SerializedScriptValue::create($value)";
    }

    if ($type eq "NodeFilter") {
        return "V8DOMWrapper::wrapNativeNodeFilter($value)";
    }

    if ($type eq "SVGRect") {
        $implIncludes{"FloatRect.h"} = 1;
    }

    if ($type eq "SVGPoint") {
        $implIncludes{"FloatPoint.h"} = 1;
    }

    # Default, assume autogenerated type conversion routines
    if ($type eq "EventTarget") {
        $implIncludes{"V8Node.h"} = 1;

        # EventTarget is not in DOM hierarchy, but all Nodes are EventTarget.
        return "V8Node::HasInstance($value) ? V8Node::toNative(v8::Handle<v8::Object>::Cast($value)) : 0";
    }

    if ($type eq "XPathNSResolver") {
        return "V8DOMWrapper::getXPathNSResolver($value)";
    }

    AddIncludesForType($type);

    if (IsDOMNodeType($type)) {
        $implIncludes{"V8${type}.h"} = 1;

        # Perform type checks on the parameter, if it is expected Node type,
        # return NULL.
        return "V8${type}::HasInstance($value) ? V8${type}::toNative(v8::Handle<v8::Object>::Cast($value)) : 0";
    } else {
        # TODO: Temporary to avoid Window name conflict.
        my $classIndex = uc($type);
        my $implClassName = ${type};

        $implIncludes{"V8$type.h"} = 1;

        if (IsPodType($type)) {
            my $nativeType = GetNativeType($type);
            $implIncludes{"V8SVGPODTypeWrapper.h"} = 1;

            return "V8SVGPODTypeUtil::toSVGPODType<${nativeType}>(V8ClassIndex::${classIndex}, $value${maybeOkParam})"
        }

        $implIncludes{"V8${type}.h"} = 1;

        # Perform type checks on the parameter, if it is expected Node type,
        # return NULL.
        return "V8${type}::HasInstance($value) ? V8${type}::toNative(v8::Handle<v8::Object>::Cast($value)) : 0";
    }
}


sub GetV8HeaderName
{
    my $type = shift;
    return "V8Event.h" if $type eq "DOMTimeStamp";
    return "EventListener.h" if $type eq "EventListener";
    return "EventTarget.h" if $type eq "EventTarget";
    return "SerializedScriptValue.h" if $type eq "SerializedScriptValue";
    return "V8${type}.h";
}


sub CreateCustomSignature
{
    my $function = shift;
    my $count = @{$function->parameters};
    my $name = $function->signature->name;
    my $result = "  const int ${name}_argc = ${count};\n" .
      "  v8::Handle<v8::FunctionTemplate> ${name}_argv[${name}_argc] = { ";
    my $first = 1;
    foreach my $parameter (@{$function->parameters}) {
        if ($first) { $first = 0; }
        else { $result .= ", "; }
        if (IsWrapperType($parameter->type)) {
            if ($parameter->type eq "XPathNSResolver") {
                # Special case for XPathNSResolver.  All other browsers accepts a callable,
                # so, even though it's against IDL, accept objects here.
                $result .= "v8::Handle<v8::FunctionTemplate>()";
            } else {
                my $type = $parameter->type;
                my $header = GetV8HeaderName($type);
                $implIncludes{$header} = 1;
                $result .= "V8${type}::GetRawTemplate()";
            }
        } else {
            $result .= "v8::Handle<v8::FunctionTemplate>()";
        }
    }
    $result .= " };\n";
    $result .= "  v8::Handle<v8::Signature> ${name}_signature = v8::Signature::New(desc, ${name}_argc, ${name}_argv);\n";
    return $result;
}


sub RequiresCustomSignature
{
    my $function = shift;
    # No signature needed for Custom function
    if ($function->signature->extendedAttributes->{"Custom"} ||
        $function->signature->extendedAttributes->{"V8Custom"}) {
        return 0;
    }

    foreach my $parameter (@{$function->parameters}) {
      if (IsWrapperType($parameter->type)) {
          return 1;
      }
    }
    return 0;
}


my %non_wrapper_types = (
    'float' => 1,
    'double' => 1,
    'short' => 1,
    'unsigned short' => 1,
    'long' => 1,
    'unsigned long' => 1,
    'boolean' => 1,
    'long long' => 1,
    'unsigned long long' => 1,
    'DOMString' => 1,
    'CompareHow' => 1,
    'SVGAngle' => 1,
    'SVGRect' => 1,
    'SVGPoint' => 1,
    'SVGPreserveAspectRatio' => 1,
    'SVGMatrix' => 1,
    'SVGTransform' => 1,
    'SVGLength' => 1,
    'SVGNumber' => 1,
    'SVGPaintType' => 1,
    'DOMTimeStamp' => 1,
    'JSObject' => 1,
    'EventTarget' => 1,
    'NodeFilter' => 1,
    'EventListener' => 1
);


sub IsWrapperType
{
    my $type = $codeGenerator->StripModule(shift);
    return !($non_wrapper_types{$type});
}

sub IsDOMNodeType
{
    my $type = shift;

    return 1 if $type eq 'Attr';
    return 1 if $type eq 'CDATASection';
    return 1 if $type eq 'Comment';
    return 1 if $type eq 'Document';
    return 1 if $type eq 'DocumentFragment';
    return 1 if $type eq 'DocumentType';
    return 1 if $type eq 'Element';
    return 1 if $type eq 'EntityReference';
    return 1 if $type eq 'HTMLCanvasElement';
    return 1 if $type eq 'HTMLDocument';
    return 1 if $type eq 'HTMLElement';
    return 1 if $type eq 'HTMLFormElement';
    return 1 if $type eq 'HTMLTableCaptionElement';
    return 1 if $type eq 'HTMLTableSectionElement';
    return 1 if $type eq 'Node';
    return 1 if $type eq 'ProcessingInstruction';
    return 1 if $type eq 'SVGElement';
    return 1 if $type eq 'SVGDocument';
    return 1 if $type eq 'SVGSVGElement';
    return 1 if $type eq 'SVGUseElement';
    return 1 if $type eq 'Text';

    return 0;
}


sub ReturnNativeToJSValue
{
    my $signature = shift;
    my $value = shift;
    my $indent = shift;
    my $type = GetTypeFromSignature($signature);

    return "return v8::Date::New(static_cast<double>($value))" if $type eq "DOMTimeStamp";
    return "return v8Boolean($value)" if $type eq "boolean";
    return "return v8::Handle<v8::Value>()" if $type eq "void";     # equivalent to v8::Undefined()

    # For all the types where we use 'int' as the representation type,
    # we use Integer::New which has a fast Smi conversion check.
    my $nativeType = GetNativeType($type);
    return "return v8::Integer::New($value)" if $nativeType eq "int";
    return "return v8::Integer::NewFromUnsigned($value)" if $nativeType eq "unsigned";

    return "return v8DateOrNull($value);" if $type eq "Date";
    return "return v8::Number::New($value)" if $codeGenerator->IsPrimitiveType($type) or $type eq "SVGPaintType";

    if ($codeGenerator->IsStringType($type)) {
        my $conv = $signature->extendedAttributes->{"ConvertNullStringTo"};
        if (defined $conv) {
            return "return v8StringOrNull($value)" if $conv eq "Null";
            return "return v8StringOrUndefined($value)" if $conv eq "Undefined";
            return "return v8StringOrFalse($value)" if $conv eq "False";

            die "Unknown value for ConvertNullStringTo extended attribute";
        }
        return "return v8String($value)";
    }

    AddIncludesForType($type);

    # special case for non-DOM node interfaces
    if (IsDOMNodeType($type)) {
        return "return toV8(${value}" . ($signature->extendedAttributes->{"ReturnsNew"} ? ", true)" : ")");
    }

    if ($type eq "EventTarget") {
        return "return V8DOMWrapper::convertEventTargetToV8Object($value)";
    }

    if ($type eq "EventListener") {
        $implIncludes{"V8AbstractEventListener.h"} = 1;
        return "return ${value} ? v8::Handle<v8::Value>(static_cast<V8AbstractEventListener*>(${value})->getListenerObject(imp->scriptExecutionContext())) : v8::Handle<v8::Value>(v8::Null())";
    }

    if ($type eq "SerializedScriptValue") {
        $implIncludes{"$type.h"} = 1;
        return "return $value->deserialize()";
    }

    $implIncludes{"wtf/RefCounted.h"} = 1;
    $implIncludes{"wtf/RefPtr.h"} = 1;
    $implIncludes{"wtf/GetPtr.h"} = 1;

    if (IsPodType($type)) {
        $value = GenerateSVGStaticPodTypeWrapper($type, $value) . ".get()";
    }

    return "return toV8($value)";
}

sub GenerateSVGStaticPodTypeWrapper {
    my $type = shift;
    my $value = shift;

    $implIncludes{"V8$type.h"}=1;
    $implIncludes{"V8SVGPODTypeWrapper.h"} = 1;

    my $nativeType = GetNativeType($type);
    return "V8SVGStaticPODTypeWrapper<$nativeType>::create($value)";
}

# Internal helper
sub WriteData
{
    if (defined($IMPL)) {
        # Write content to file.
        print $IMPL @implContentHeader;

        print $IMPL @implFixedHeader;

        foreach my $implInclude (sort keys(%implIncludes)) {
            my $checkType = $implInclude;
            $checkType =~ s/\.h//;

            print $IMPL "#include \"$implInclude\"\n" unless $codeGenerator->IsSVGAnimatedType($checkType);
        }

        print $IMPL "\n";
        print $IMPL @implContentDecls;
        print $IMPL @implContent;
        close($IMPL);
        undef($IMPL);

        %implIncludes = ();
        @implFixedHeader = ();
        @implHeaderContent = ();
        @implContentDecls = ();
        @implContent = ();
    }

    if (defined($HEADER)) {
        # Write content to file.
        print $HEADER @headerContent;
        close($HEADER);
        undef($HEADER);

        @headerContent = ();
    }
}

sub IsSVGTypeNeedingContextParameter
{
    my $implClassName = shift;

    if ($implClassName =~ /SVG/ and not $implClassName =~ /Element/) {
        return 1 unless $implClassName =~ /SVGPaint/ or $implClassName =~ /SVGColor/ or $implClassName =~ /SVGDocument/;
    }

    return 0;
}

sub GenerateSVGContextAssignment
{
    my $srcType = shift;
    my $value = shift;
    my $indent = shift;

    $result = GenerateSVGContextRetrieval($srcType, $indent);
    $result .= $indent . "V8Proxy::setSVGContext($value, context);\n";

    return $result;
}

sub GenerateSVGContextRetrieval
{
    my $srcType = shift;
    my $indent = shift;

    my $srcIsPodType = IsPodType($srcType);

    my $srcObject = "imp";
    if ($srcIsPodType) {
        $srcObject = "imp_wrapper";
    }

    my $contextDecl;

    if (IsSVGTypeNeedingContextParameter($srcType)) {
        $contextDecl = "V8Proxy::svgContext($srcObject)";
    } else {
        $contextDecl = $srcObject;
    }

    return $indent . "SVGElement* context = $contextDecl;\n";
}

sub IsSVGListMutator
{
    my $functionName = shift;

    return 1 if $functionName eq "clear";
    return 1 if $functionName eq "initialize";
    return 1 if $functionName eq "insertItemBefore";
    return 1 if $functionName eq "replaceItem";
    return 1 if $functionName eq "removeItem";
    return 1 if $functionName eq "appendItem";

    return 0;
}

sub IsSVGListMethod
{
    my $functionName = shift;

    return 1 if $functionName eq "getFirst";
    return 1 if $functionName eq "getLast";
    return 1 if $functionName eq "getItem";

    return IsSVGListMutator($functionName);
}

sub IsSVGListTypeNeedingSpecialHandling
{
    my $className = shift;

    return 1 if $className eq "SVGPointList";
    return 1 if $className eq "SVGTransformList";

    return 0;
}

sub DebugPrint
{
    my $output = shift;

    print $output;
    print "\n";
}
