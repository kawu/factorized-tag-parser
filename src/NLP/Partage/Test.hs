{-# LANGUAGE OverloadedStrings #-}


-- | A monad for defining elementary trees with FS unification.


module NLP.Partage.Test
( theTest
) where


-- import           Control.Monad (foldM)

-- import qualified Control.Monad.State.Strict as E
import qualified Data.Text as T
import qualified Data.Tree as R
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import           Data.Maybe (mapMaybe)

import qualified NLP.Partage.FS as FS
import qualified NLP.Partage.FSTree as FST
import           NLP.Partage.FSTree (FSTree, node, leaf, foot, term)
import qualified NLP.Partage.Env as Env
import qualified NLP.Partage.DAG as DAG
import qualified NLP.Partage.Tree.Other as O

import qualified NLP.Partage.Auto.Trie as Trie

import qualified NLP.Partage.Earley.Comp as C
import qualified NLP.Partage.Earley as Earley


--------------------------------------------------
-- Utility types
--------------------------------------------------


type Tree n t = R.Tree (O.Node n t)

--------------------------------------------------
-- Tests
--------------------------------------------------


-- | Non-terminal.
type N = T.Text

-- | Terminal.
type T = T.Text

-- | FS key.
type K = T.Text

-- | FS value.
type V = T.Text


-- | Predefined keys
num, sg3 :: K
num = "num"
sg3 = "sg3"


girl :: Env.EnvM V (FSTree N T K)
girl = do
  numVar <- Env.var
  sg3Var <- Env.var
  let fs = M.fromList
        [ (num, numVar)
        , (sg3, sg3Var) ]
  return $
    node "NP" fs
    [ node "N" fs
      [ term "girl" fs]
    ]


sleep :: Env.EnvM V (FSTree N T K)
sleep = do
  sg3Var <- Env.var
  let no = M.empty
      fs = M.fromList
        [ (sg3, sg3Var) ]
  return $
    node "S" no
    [ leaf "NP" fs
    , node "VP" fs
      [ node "V" fs
        [term "sleep" fs]
      ]
    ]


many :: Env.EnvM V (FSTree N T K)
many = do
  numVar <- Env.var
  let fs = M.fromList [(num, numVar)]
  return $
    node "N" fs
    [ node "Adj" fs [term "many" fs]
    , foot "N"
    ]


-- | A simple TAG grammar.
gram :: [(Tree N T, C.Comp (FS.CFS K V))]
gram = mapMaybe process
  [girl, sleep, many]
  where
    process source = do
      let comp = FST.compile source
      tree <- fmap fst <$> FST.extract source
      return (tree, comp)


theTest :: IO ()
theTest = do
  let dag = DAG.mkGramWith C.or gram
      tri = Trie.fromGram (DAG.factGram dag)
      aut = Earley.mkAuto (DAG.dagGram dag) tri
  trees <- Earley.parseAuto aut "S" $ Earley.fromList
    [ ("many", M.fromList [(num, val 0 "pl")])
    , ("girl", M.fromList [(sg3, val 0 "-"), (num, val 1 "pl")])
    , ("sleep", M.fromList [(sg3, val 0 "-")]) ]
  mapM_ printTree trees
  where
    printTree = putStrLn . R.drawTree . fmap show . O.encode . Left
    -- mkPair x y = (x, Just $ S.singleton y)
    val i = FS.Val i . Just . S.singleton


--------------------------------------------------
-- Utils
--------------------------------------------------


-- -- | Get the FS under the given path.
-- under :: [Int] -> R.Tree (Maybe [a]) -> [a]
-- under path t = maybe [] id $ do
--   subTree <- follow path t
--   R.rootLabel subTree
--
--
-- -- | Follow the path to a particular subtree.
-- follow :: [Int] -> R.Tree a -> Maybe (R.Tree a)
-- follow = flip $ foldM step
--
--
-- -- | Follow one step of the `Path`.
-- step :: R.Tree a -> Int -> Maybe (R.Tree a)
-- step t k = R.subForest t !? k
--
--
-- -- | Maybe a k-th element of a list.
-- (!?) :: [a] -> Int -> Maybe a
-- (x:xs) !? k
--     | k > 0     = xs !? (k-1)
--     | otherwise = Just x
-- [] !? _ = Nothing
