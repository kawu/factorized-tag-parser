{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE ScopedTypeVariables #-}


module NLP.Partage.AStar.Deriv
( Deriv
, DerivNode (..)
, derivTrees
, derivFromPassive
-- , deriv2tree
-- , expandDeriv
-- -- , fromPassive'
-- -- , fromActive'
) where


import           Data.Lens.Light
import           Data.Maybe             (maybeToList)
import qualified Data.Set               as S
import qualified Data.Tree              as R

import qualified NLP.Partage.AStar      as A
import qualified NLP.Partage.Tree.Other as O


---------------------------
-- Extracting Derivation Trees
--
-- Experimental version
---------------------------


-- | Derivation tree is similar to `O.Tree` but additionally includes
-- potential modifications aside the individual nodes.  Modifications
-- themselves take the form of derivation trees.  Whether the modification
-- represents a substitution or an adjunction can be concluded on the basis of
-- the type (leaf or internal) of the node.
type Deriv n t = R.Tree (DerivNode n t)


-- | A node of a derivation tree.
data DerivNode n t = DerivNode
  { node  :: O.Node n t
  , modif :: [Deriv n t]
  } deriving (Eq, Ord, Show)


-- | Extract derivation trees obtained on the given input sentence. Should be
-- run on the final result of the earley parser.
derivTrees
    :: (Ord n, Ord t)
    => A.Hype n t     -- ^ Final state of the earley parser
    -> n            -- ^ The start symbol
    -> Int          -- ^ Length of the input sentence
    -> [Deriv n t]
derivTrees hype start n
    = concatMap (`derivFromPassive` hype)
    $ A.finalFrom start n hype


-- | Extract the set of the parsed trees w.r.t. to the given passive item.
derivFromPassive :: forall n t. (Ord n, Ord t) => A.Passive n t -> A.Hype n t -> [Deriv n t]
derivFromPassive passive hype = concat

  [ fromPassiveTrav passive trav
  | ext <- maybeToList $ A.passiveTrav passive hype
  , trav <- S.toList (A.prioTrav ext) ]

  where

    passiveDerivs = flip derivFromPassive hype

    fromPassiveTrav p (A.Scan q t _) =
        [ mkTree p (termNode t) ts
        | ts <- activeDerivs q ]
    fromPassiveTrav p (A.Foot q _p' _) =
        [ mkTree p (footNode p) ts
        | ts <- activeDerivs q ]
    fromPassiveTrav p (A.Subst qp qa _) =
        [ mkTree p (substNode t) ts
        | ts <- activeDerivs qa
        , t  <- passiveDerivs qp ]
    fromPassiveTrav _p (A.Adjoin qa qm) =
        [ adjoinTree ini aux
        | aux <- passiveDerivs qa
        , ini <- passiveDerivs qm ]

    -- Construct a derivation tree on the basis of the underlying passive
    -- item, current child derivation and previous children derivations.
    mkTree p t ts = R.Node
      { R.rootLabel = mkRoot p
      , R.subForest = reverse $ t : ts }

    -- Extract the set of the parsed trees w.r.t. to the given active item.
    activeDerivs active = case A.activeTrav active hype of
      Nothing  -> error "activeDerivs: unknown active item"
      Just ext -> if S.null (A.prioTrav ext)
        then [[]]
        else concatMap
             (fromActiveTrav active)
             (S.toList (A.prioTrav ext))

    fromActiveTrav _p (A.Scan q t _) =
        [ termNode t : ts
        | ts <- activeDerivs q ]
    fromActiveTrav _p (A.Foot q p _) =
        [ footNode p : ts
        | ts <- activeDerivs q ]
    fromActiveTrav _p (A.Subst qp qa _) =
        [ substNode t : ts
        | ts <- activeDerivs qa
        , t  <- passiveDerivs qp ]
    fromActiveTrav _p (A.Adjoin _ _) =
        error "activeDerivs.fromActiveTrav: called on a passive item"

    -- Construct substitution node stemming from the given derivation.
    substNode t = flip R.Node [] $ DerivNode
      { node = O.NonTerm (derivRoot t)
      , modif   = [t] }

    -- Add the auxiliary derivation to the list of modifications of the
    -- initial derivation.
    adjoinTree ini aux = R.Node
      { R.rootLabel = let root = R.rootLabel ini in DerivNode
        { node = node root
        , modif = aux : modif root }
      , R.subForest = R.subForest ini }

    -- Construct a derivation node with no modifier.
    only x = DerivNode {node = x, modif =  []}

    -- Several constructors which allow to build non-modified nodes.
    mkRoot p = only . O.NonTerm $ A.nonTerm (getL A.dagID p) hype
    mkFoot p = only . O.Foot $ A.nonTerm (getL A.dagID p) hype
    mkTerm = only . O.Term

    -- Build non-modified nodes of different types.
    footNode p = R.Node (mkFoot p) []
    termNode x = R.Node (mkTerm x) []

    -- Retrieve root non-terminal of a derivation tree.
    derivRoot :: Deriv n t -> n
    derivRoot R.Node{..} = case node rootLabel of
      O.NonTerm x -> x
      O.Foot _ -> error "passiveDerivs.getRoot: got foot"
      O.Term _ -> error "passiveDerivs.getRoot: got terminal"
