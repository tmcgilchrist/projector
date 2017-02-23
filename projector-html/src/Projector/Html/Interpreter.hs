{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
module Projector.Html.Interpreter (
    Html (..)
  , Attribute (..)
  ---
  , InterpretError (..)
  , interpret
  ) where

import           Data.Map (Map)

import           P

import           Projector.Core.Eval
import           Projector.Core.Syntax
import           Projector.Core.Type
import           Projector.Html.Data.Prim

data Html =
    Plain !Text
  | Raw !Text
  | Whitespace !Text
  | Comment !Text
  | Element !Text ![Attribute] !Html
  | VoidElement !Text ![Attribute]
  | Nested ![Html]
  deriving (Eq, Show)

instance Monoid Html where
  mempty =
    Nested mempty
  mappend h1 h2 =
    let
      nested hs =
        case hs of
          h : [] ->
            h
          _ ->
            Nested hs
    in
      case (h1, h2) of
        (Nested n1, Nested n2) ->
          nested (n1 <> n2)
        (Nested n1, _) ->
          nested (n1 <> [h2])
        (_, Nested n2) ->
          nested (h1 : n2)
        _ ->
          Nested [h1, h2]

data Attribute =
  Attribute !Text !Text
  deriving (Eq, Show)

data InterpretError a =
    InterpretInvalidExpression (HtmlExpr a)
  deriving (Eq, Show)

interpret :: Map Name (HtmlExpr a) -> HtmlExpr a -> Either (InterpretError a) Html
interpret bnds =
  interpret' . nf bnds

interpret' :: HtmlExpr a -> Either (InterpretError a) Html
interpret' e =
  case e of
    ECon _ c _ es ->
      case (c, es) of
        (Constructor "Plain", [ELit _ (VString t)]) ->
           pure $ Plain t
        (Constructor "Raw", [ELit _ (VString t)]) ->
           pure $ Raw t
        (Constructor "Whitespace", []) ->
           pure $ Whitespace " "
        (Constructor "Comment", [ELit _ (VString t)]) ->
           pure $ Comment t
        (Constructor "Element", [ECon _ (Constructor "Tag") _ [(ELit _ (VString t))], EList _ attrs, body]) -> do
           Element
             <$> pure t
             <*> mapM attr attrs
             <*> interpret' body
        (Constructor "VoidElement", [ECon _ (Constructor "Tag") _ [(ELit _ (VString t))], EList _ attrs]) -> do
           VoidElement
             <$> pure t
             <*> mapM attr attrs
        (Constructor "Nested", [EList _ nodes]) ->
          fmap mconcat . mapM interpret' $ nodes
        _ ->
          Left $ InterpretInvalidExpression e
    ECase _ _ _ ->
      -- FIX Not implemented, but this lets us test it without failures
      pure $ Plain "TODO"
    EApp _ (EVar _ (Name "text")) v ->
      Plain
        <$> value v
    EApp _ _ _ ->
      Left $ InterpretInvalidExpression e
    ELam _ _ _ _ ->
      Left $ InterpretInvalidExpression e
    EList _ _ ->
      Left $ InterpretInvalidExpression e
    EMap _ _ _ ->
      Left $ InterpretInvalidExpression e
    ELit _ _ ->
      Left $ InterpretInvalidExpression e
    EVar _ _ ->
      Left $ InterpretInvalidExpression e
    EForeign _ _ _ ->
      Left $ InterpretInvalidExpression e

-- | Guaranteed to return text, not html
value :: HtmlExpr a -> Either (InterpretError a) Text
value e =
  case e of
    ELit _ (VString v) ->
      pure v
    EApp _ (EForeign _ (Name "concat") _) (EList _ as) ->
      fmap mconcat . mapM value $ as
    ECase _ _ _ ->
      -- FIX Not implemented, but this lets us test it without failures
      pure "TODO"
    _ ->
      Left $ InterpretInvalidExpression e

attr :: HtmlExpr a -> Either (InterpretError a) Attribute
attr e =
  case e of
    ECon _ (Constructor "Attribute") _ [ECon _ (Constructor "AttributeKey") _ [ELit _ (VString k)], ECon _ (Constructor "AttributeValue") _ [v]] ->
      Attribute k <$> value v
    _ ->
      Left $ InterpretInvalidExpression e