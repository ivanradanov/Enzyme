; RUN: %opt < %s %loadEnzyme -enzyme -enzyme_preopt=false -mem2reg -sroa -simplifycfg -instcombine -early-cse -adce -S | FileCheck %s

%Type = type { float, double }

declare dso_local double @__enzyme_autodiff(i8*, ...)

; Function Attrs: alwaysinline norecurse nounwind uwtable
define double @caller(%Type* %K, %Type* %Kp) local_unnamed_addr #0 {
entry:
  %call86 = call double (i8*, ...) @__enzyme_autodiff(i8* bitcast (void (%Type*)* @matvec to i8*), metadata !"diffe_dup", %Type* noalias %K, %Type* noalias %Kp) #4
  ret double %call86
}

define internal void @matvec(%Type* %evaluator.i.i) {
entry:
  %dims = getelementptr inbounds %Type, %Type* %evaluator.i.i, i64 0, i32 1
  %call = call double @total(double* %dims) #4
  %flt = fptrunc double %call to float
  %data = getelementptr inbounds %Type, %Type* %evaluator.i.i, i64 0, i32 0
  store float %flt, float* %data, align 4
  ret void
}

; Function Attrs: readnone
define double @meta(double %inp) #3 {
entry:
  %arr = alloca double
  store double %inp, double* %arr
  %call.i = call double* @sub(double* %arr)
  %a1 = load double, double* %call.i
  %mul = fmul double %a1, %a1
  ret double %mul
}

define double* @sub(double* %a) {
entry:
  ret double* %a
}

define double @total(double* %this) {
entry:
  %loaded = load double, double* %this
  %mcall = tail call double @meta(double %loaded)
  ret double %mcall
}

attributes #3 = { readnone }

; CHECK: define internal {} @diffematvec(%Type* %evaluator.i.i, %Type* %"evaluator.i.i'") {
; CHECK-NEXT: entry:
; CHECK-NEXT:   %[[dimsipge:.+]] = getelementptr inbounds %Type, %Type* %"evaluator.i.i'", i64 0, i32 1
; CHECK-NEXT:   %dims = getelementptr inbounds %Type, %Type* %evaluator.i.i, i64 0, i32 1
; CHECK-NEXT:   %call_augmented = call { {}, double } @augmented_total(double* nonnull %dims, double* nonnull %[[dimsipge]])
; CHECK-NEXT:   %call = extractvalue { {}, double } %call_augmented, 1
; CHECK-NEXT:   %flt = fptrunc double %call to float
; CHECK-NEXT:   %data = getelementptr inbounds %Type, %Type* %evaluator.i.i, i64 0, i32 0
; CHECK-NEXT:   store float %flt, float* %data, align 4
; CHECK-NEXT:   %[[dataipge:.+]] = getelementptr inbounds %Type, %Type* %"evaluator.i.i'", i64 0, i32 0
; CHECK-NEXT:   %0 = load float, float* %[[dataipge:.+]], align 4
; CHECK-NEXT:   store float 0.000000e+00, float* %[[dataipge:.+]], align 4
; CHECK-NEXT:   %1 = fpext float %0 to double
; CHECK-NEXT:   %[[unused:.+]] = call {} @diffetotal(double* nonnull %dims, double* nonnull %[[dimsipge]], double %1, {} undef)
; CHECK-NEXT:   ret {} undef
; CHECK-NEXT: }

; CHECK: define internal { {}, double } @augmented_total(double* %this, double* %"this'") {
; CHECK-NEXT: entry:
; CHECK-NEXT:   %loaded = load double, double* %this, align 8
; CHECK-NEXT:   %mcall = tail call double @meta(double %loaded)
; CHECK-NEXT:   %.fca.1.insert = insertvalue { {}, double } undef, double %mcall, 1
; CHECK-NEXT:   ret { {}, double } %.fca.1.insert
; CHECK-NEXT: }

; CHECK: define internal {} @diffetotal(double* %this, double* %"this'", double %differeturn, {} %tapeArg) {
; CHECK-NEXT: entry:
; CHECK-NEXT:   %[[loaded:.+]] = load double, double* %this, align 8
; CHECK-NEXT:   %[[dmetastruct:.+]] = call { double } @diffemeta(double %[[loaded]], double %differeturn)
; CHECK-NEXT:   %[[dmeta:.+]] = extractvalue { double } %[[dmetastruct]], 0
; CHECK-NEXT:   %[[prethis:.+]] = load double, double* %"this'", align 8
; CHECK-NEXT:   %[[postthis:.+]] = fadd fast double %[[prethis]], %[[dmeta]]
; CHECK-NEXT:   store double %[[postthis:.+]], double* %"this'", align 8
; CHECK-NEXT:   ret {} undef
; CHECK-NEXT: }

; CHECK: define internal { double } @diffemeta(double %inp, double %differeturn) #0 {
; CHECK-NEXT: entry:
; CHECK-NEXT:   %"arr'ipa" = alloca double, align 8
; CHECK-NEXT:   %0 = bitcast double* %"arr'ipa" to i64*
; CHECK-NEXT:   store i64 0, i64* %0, align 8
; CHECK-NEXT:   %arr = alloca double, align 8
; CHECK-NEXT:   store double %inp, double* %arr, align 8
; CHECK-NEXT:   %call.i_augmented = call { {}, double*, double* } @augmented_sub(double*{{( nonnull)?}} %arr, double*{{( nonnull)?}} %"arr'ipa")
; CHECK-NEXT:   %[[olddptr:.+]] = extractvalue { {}, double*, double* } %call.i_augmented, 2
; CHECK-NEXT:   %[[oldptr:.+]] = extractvalue { {}, double*, double* } %call.i_augmented, 1
; CHECK-NEXT:   %[[load:.+]] = load double, double* %[[oldptr]]
; CHECK-NEXT:   %[[add:.+]] = fadd fast double %differeturn, %differeturn
; CHECK-NEXT:   %[[mul:.+]] = fmul fast double %[[load]], %[[add]]
; CHECK-NEXT:   %3 = load double, double* %"call.i'ac", align 8
; CHECK-NEXT:   %4 = fadd fast double %3, %2
; CHECK-NEXT:   store double %4, double* %"call.i'ac", align 8
; CHECK-NEXT:   %{{.*}} = call {} @diffesub(double*{{( nonnull)?}} %arr, double*{{( nonnull)?}} %"arr'ipa", {} undef)
; CHECK-NEXT:   %[[darr:.+]] = load double, double* %"arr'ipa", align 8
; CHECK-NEXT:   store double 0.000000e+00, double* %"arr'ipa", align 8
; CHECK-NEXT:   %[[ret:.+]] = insertvalue { double } undef, double %[[darr]], 0
; CHECK-NEXT:   ret { double } %[[ret]]
; CHECK-NEXT: }

; TODO don't need the diffe ret
; CHECK: define internal { {}, double*, double* } @augmented_sub(double* %a, double* %"a'") {
; CHECK-NEXT: entry:
; CHECK-NEXT:   %.fca.1.insert = insertvalue { {}, double*, double* } undef, double* %a, 1
; CHECK-NEXT:   %.fca.2.insert = insertvalue { {}, double*, double* } %.fca.1.insert, double* %"a'", 2
; CHECK-NEXT:   ret { {}, double*, double* } %.fca.2.insert
; CHECK-NEXT: }

; CHECK: define internal {} @diffesub(double* %a, double* %"a'", {} %tapeArg) {
; CHECK-NEXT: entry:
; CHECK-NEXT:   ret {} undef
; CHECK-NEXT: }