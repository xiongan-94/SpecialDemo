/*
 * Scala (https://www.scala-lang.org)
 *
 * Copyright EPFL and Lightbend, Inc.
 *
 * Licensed under Apache License 2.0
 * (http://www.apache.org/licenses/LICENSE-2.0).
 *
 * See the NOTICE file distributed with this work for
 * additional information regarding copyright ownership.
 */

package scala

/**
 * An annotation on methods that forbids the compiler to inline the method, no matter how safe the
 * inlining appears to be. The annotation can be used at definition site or at callsite.
 *
 * {{{
 * @inline   final def f1(x: Int) = x
 * @noinline final def f2(x: Int) = x
 *           final def f3(x: Int) = x
 *
 *  def t1 = f1(1)              // inlined if possible
 *  def t2 = f2(1)              // not inlined
 *  def t3 = f3(1)              // may be inlined (heuristics)
 *  def t4 = f1(1): @noinline   // not inlined (override at callsite)
 *  def t5 = f2(1): @inline     // inlined if possible (override at callsite)
 *  def t6 = f3(1): @inline     // inlined if possible
 *  def t7 = f3(1): @noinline   // not inlined
 * }
 * }}}
 *
 * Note: parentheses are required when annotating a callsite within a larger expression.
 *
 * {{{
 * def t1 = f1(1) + f1(1): @noinline   // equivalent to (f1(1) + f1(1)): @noinline
 * def t2 = f1(1) + (f1(1): @noinline) // the second call to f1 is not inlined
 * }}}
 *
 * @author Lex Spoon
 * @since 2.5
 */
class noinline extends scala.annotation.StaticAnnotation
