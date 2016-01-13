{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE FlexibleContexts #-}


-- | A version where the grammar is actually compressed to a form of
-- a single /directed acyclic word graph/, i.e. a
-- /minimal finite state automaton/.


module NLP.TAG.Vanilla.Auto.DAWG
(
-- -- * DAWG
--   DAWG
-- , buildAuto
-- 
-- -- * Interface
-- , shell
  fromGram
) where


-- import qualified Control.Monad.State.Strict as E
-- import           Control.Monad.Trans.Class (lift)

import qualified Data.Set                   as S

-- import           Data.DAWG.Ord (ID)
import qualified Data.DAWG.Ord              as D

import           NLP.TAG.Vanilla.FactGram
    ( FactGram, Lab(..), Rule(..) )


import qualified NLP.TAG.Vanilla.Auto as A


--------------------------------------------------
-- Interface
--------------------------------------------------


-- -- | DAWG as automat with one parameter.
-- newtype Auto a = Auto { unAuto :: D.DAWG a () }


-- | Abstract over the concrete representation of the grammar
-- automaton.
shell :: (Ord n, Ord t) => DAWG n t -> A.GramAuto n t
shell d = A.Auto
    { roots  = S.singleton (D.root d)
    , follow = \i x ->  D.follow i x d
    , edges  = flip D.edges d }


-- | Build the DAWG-based representation of the given grammar.
fromGram :: (Ord n, Ord t) => FactGram n t -> A.GramAuto n t
fromGram = shell . buildAuto


--------------------------------------------------
-- Implementation
--------------------------------------------------


-- | The automaton-based representation of a factorized TAG
-- grammar.  Left transitions contain non-terminals belonging to
-- body non-terminals while Right transitions contain rule heads
-- non-terminals.
type DAWG n t = D.DAWG (A.Edge (Lab n t)) ()


-- | Build automaton from the given grammar.
buildAuto :: (Ord n, Ord t) => FactGram n t -> DAWG n t
buildAuto gram = D.fromLang
    [ map A.Body bodyR ++ [A.Head headR]
    | Rule{..} <- S.toList gram ]


-- -- | Return the list of automaton transitions.
-- edges :: (Ord n, Ord t) => DAWG n t -> [(ID, Edge (Lab n t), ID)]
-- edges = S.toList . walk
--
--
-- -- | Traverse  the automaton and collect all the edges.
-- --
-- -- TODO: it is provided in the general case in the `Mini` module.
-- -- Remove the version below.
-- walk
--     :: (Ord n, Ord t)
--     => DAWG n t
--     -> S.Set (ID, Edge (Lab n t), ID)
-- walk dawg =
--     flip E.execState S.empty $
--         flip E.evalStateT S.empty $
--             doit (D.root dawg)
--   where
--     -- The embedded state serves to store the resulting set of
--     -- transitions; the surface state serves to keep track of
--     -- already visited nodes.
--     doit i = do
--         b <- E.gets $ S.member i
--         E.when (not b) $ do
--             E.modify $ S.insert i
--             E.forM_ (D.edges i dawg) $ \(x, j) -> do
--                 E.lift . E.modify $ S.insert (i, x, j)
--                 doit j
