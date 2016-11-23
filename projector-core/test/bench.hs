{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}


import           Criterion.Main (defaultConfig, defaultMainWith, bgroup, bench)
import           Criterion.Types (Config (..))
import qualified Criterion.Main as C

import           P

import           Projector.Core

import           System.IO (IO)

import           Test.Projector.Core.Arbitrary
import           Test.Projector.Core.Simplify (mul, nth)


-- big lambda billy

buildExpr :: Int -> Expr TestLitT ()
buildExpr n = case n of
  0 -> var_ "billy"
  m -> app (lam_ "billy" (TLit TBool) (buildExpr (m - 1))) (lit (VBool True))

-- big case

buildCase :: Int -> Expr TestLitT ()
buildCase n = case n of
  0 -> var_ "x"
  m -> case_ (con (Constructor "Casey") (TypeName "Casey") [lit (VBool True)]) [(pcon_ "Casey" [pvar_ "x"], buildCase (m-1))]

tcasey :: Decl TestLitT
tcasey =
  DVariant [(Constructor "Casey", [TLit TBool])]

caseyCtx :: TypeDecls TestLitT
caseyCtx =
  declareType (TypeName "Casey") tcasey mempty

-- intlist

buildIntList :: Int -> Expr TestLitT ()
buildIntList n = case n of
  0 -> tnil
  _ -> tcons n (buildIntList (n - 1))

dintlist :: Decl TestLitT
dintlist =
  DVariant [
      (Constructor "Nil", [])
    , (Constructor "Cons", [TLit TInt, TVar (TypeName "IntList")])
    ]

tintlistctx :: TypeDecls TestLitT
tintlistctx =
  declareType (TypeName "IntList") dintlist mempty

tnil :: Expr TestLitT ()
tnil =
  con (Constructor "Nil") (TypeName "IntList") []

tcons :: Int -> Expr TestLitT () -> Expr TestLitT ()
tcons v l =
  con (Constructor "Cons") (TypeName "IntList") [lit (VInt v), l]

main :: IO ()
main = do
  let cfg =
        defaultConfig {
            reportFile = Just "dist/build/projector-bench.html"
          , csvFile = Just "dist/build/projector-bench.csv"
          }

      norm f = C.whnf nf . f
      tc f c = C.whnf (typeCheck c) . f
      mul2 = mul 2

  defaultMainWith cfg [
      bgroup "normalise-intlist" [
          bench "normalise-intlist-100" $ norm buildIntList 100
        , bench "normalise-intlist-200" $ norm buildIntList 200
        , bench "normalise-intlist-1000" $ norm buildIntList 1000
        ]
    , bgroup "check-intlist" [
          bench "check-intlist-100" $ tc buildIntList tintlistctx 100
        , bench "check-intlist-200" $ tc buildIntList tintlistctx 200
        , bench "check-intlist-1000" $ tc buildIntList tintlistctx 1000
        ]
    , bgroup "normalise-billy" [
          bench "normalise-billy-100" $ norm buildExpr 100
        , bench "normalise-billy-200" $ norm buildExpr 200
        , bench "normalise-billy-1000" $ norm buildExpr 1000
        ]
    , bgroup "check-billy" [
          bench "check-billy-100" $ tc buildExpr mempty 100
        , bench "check-billy-200" $ tc buildExpr mempty 200
        , bench "check-billy-1000" $ tc buildExpr mempty 1000
        ]
    , bgroup "normalise-church" [
          bench "normalise-church-100" $ norm nth 100
        , bench "normalise-church-200" $ norm nth 200
        , bench "normalise-church-1000" $ norm nth 1000
        ]
    , bgroup "check-church" [
          bench "check-church-100" $ tc nth mempty 100
        , bench "check-church-200" $ tc nth mempty 200
        , bench "check-church-1000" $ tc nth mempty 1000
        ]
    , bgroup "normalise-church-mul2" [
          bench "normalise-church-mul2-100" $ norm mul2 100
        , bench "normalise-church-mul2-200" $ norm mul2 200
        , bench "normalise-church-mul2-1000" $ norm mul2 1000
        ]
    , bgroup "check-church-mul2" [
          bench "check-church-mul2-100" $ tc mul2 mempty 100
        , bench "check-church-mul2-200" $ tc mul2 mempty 200
        , bench "check-church-mul2-1000" $ tc mul2 mempty 1000
        ]
    , bgroup "normalise-casey" [
          bench "normalise-casey-100" $ norm buildCase 100
        , bench "normalise-casey-200" $ norm buildCase 200
        , bench "normalise-casey-1000" $ norm buildCase 1000
        ]
    , bgroup "check-casey" [
          bench "check-casey-100" $ tc buildCase caseyCtx 100
        , bench "check-casey-200" $ tc buildCase caseyCtx 200
        , bench "check-casey-1000" $ tc buildCase caseyCtx 1000
        ]
    ]
