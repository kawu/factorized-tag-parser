{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}


-- | A module collecting the toy grammars used for testing and
-- unit test examples themselves.


module NLP.TAG.Vanilla.Tests
( Test (..)
, TestRes (..)
, mkGram1
, gram1Tests
, mkGram2
, gram2Tests
, mkGram3
, gram3Tests
, mkGram4
, gram4Tests

, Gram
, WeightedGram
, testTree
)  where


import           Control.Applicative ((<$>), (<*>))

import qualified Data.Set as S
import qualified Data.Map.Strict as M

import           Test.Tasty (TestTree, testGroup, withResource)
import           Test.HUnit (Assertion, (@?=))
import           Test.Tasty.HUnit (testCase)

import           NLP.TAG.Vanilla.Core (Cost)
import           NLP.TAG.Vanilla.Tree (Tree (..), AuxTree (..))
import           NLP.TAG.Vanilla.Rule (Rule)
import qualified NLP.TAG.Vanilla.WRule as W
import           NLP.TAG.Vanilla.SubtreeSharing (compile)


---------------------------------------------------------------------
-- Prerequisites
---------------------------------------------------------------------


type Tr    = Tree String String
type AuxTr = AuxTree String String
type Rl    = Rule String String
type WRl   = W.Rule String String


-- | A compiled grammar.
type Gram  = S.Set Rl

-- | A compiled grammar with weights.
type WeightedTree  = (Tr, Cost)
type WeightedGram  = S.Set WRl


---------------------------------------------------------------------
-- Tests
---------------------------------------------------------------------


-- | A single test case.
data Test = Test {
    -- | Starting symbol
      startSym  :: String
    -- | The sentence to parse (list of words)
    , testSent  :: [String]
    -- | The expected recognition result
    , testRes   :: TestRes
    } deriving (Show, Eq, Ord)


-- | The expected test result.  The set of parsed trees can be optionally
-- specified.
data TestRes
    = No
    -- ^ No parse
    | Yes
    -- ^ Parse
    | Trees (S.Set Tr)
    -- ^ Parsing results
    | WeightedTrees (M.Map Tr Cost)
    -- ^ Parsing results with weights
    deriving (Show, Eq, Ord)


---------------------------------------------------------------------
-- Grammar1
---------------------------------------------------------------------


tom :: Tr
tom = INode "NP"
    [ INode "N"
        [FNode "Tom"]
    ]


sleeps :: Tr
sleeps = INode "S"
    [ INode "NP" []
    , INode "VP"
        [INode "V" [FNode "sleeps"]]
    ]


caught :: Tr
caught = INode "S"
    [ INode "NP" []
    , INode "VP"
        [ INode "V" [FNode "caught"]
        , INode "NP" [] ]
    ]


almost :: AuxTr
almost = AuxTree (INode "V"
    [ INode "Ad" [FNode "almost"]
    , INode "V" []
    ]) [1]


quickly :: AuxTr
quickly = AuxTree (INode "V"
    [ INode "Ad" [FNode "quickly"]
    , INode "V" []
    ]) [1]


a :: Tr
a = INode "D" [FNode "a"]


mouse :: Tr
mouse = INode "NP"
    [ INode "D" []
    , INode "N"
        [FNode "mouse"]
    ]


-- | Compile the first grammar.
mkGram1 :: IO Gram
mkGram1 = compile $
    map Left [tom, sleeps, caught, a, mouse] ++
    map Right [almost, quickly]


---------------------------------------------------------------------
-- Grammar1 Tests
---------------------------------------------------------------------


gram1Tests :: [Test]
gram1Tests =
    -- group 1
    [ Test "S" ["Tom", "sleeps"] . Trees . S.singleton $
        INode "S"
            [ INode "NP"
                [ INode "N"
                    [FNode "Tom"]
                ]
            , INode "VP"
                [INode "V" [FNode "sleeps"]]
            ]
    , Test "S" ["Tom"] No
    , Test "NP" ["Tom"] Yes
    -- group 2
    , Test "S" ["Tom", "almost", "caught", "a", "mouse"] . Trees . S.singleton $
        INode "S"
            [ INode "NP"
                [ INode "N"
                    [ FNode "Tom" ] ]
            , INode "VP"
                [ INode "V"
                    [ INode "Ad"
                        [FNode "almost"]
                    , INode "V"
                        [FNode "caught"]
                    ]
                , INode "NP"
                    [ INode "D"
                        [FNode "a"]
                    , INode "N"
                        [FNode "mouse"]
                    ]
                ]
            ]
    , Test "S" ["Tom", "caught", "almost", "a", "mouse"] No
    , Test "S" ["Tom", "quickly", "almost", "caught", "Tom"] Yes
    , Test "S" ["Tom", "caught", "a", "mouse"] Yes
    , Test "S" ["Tom", "caught", "Tom"] Yes
    , Test "S" ["Tom", "caught", "a", "Tom"] No
    , Test "S" ["Tom", "caught"] No
    , Test "S" ["caught", "a", "mouse"] No ]


---------------------------------------------------------------------
-- Grammar2
---------------------------------------------------------------------


alpha :: Tr
alpha = INode "S"
    [ INode "X"
        [FNode "e"] ]


beta1 :: AuxTr
beta1 = AuxTree (INode "X"
    [ FNode "a"
    , INode "X"
        [ INode "X" []
        , FNode "a" ] ]
    ) [1,0]


beta2 :: AuxTr
beta2 = AuxTree (INode "X"
    [ FNode "b"
    , INode "X"
        [ INode "X" []
        , FNode "b" ] ]
    ) [1,0]


mkGram2 :: IO Gram
mkGram2 = compile $
    map Left [alpha] ++
    map Right [beta1, beta2]


---------------------------------------------------------------------
-- Grammar2 Tests
---------------------------------------------------------------------


-- | What we test is not really a copy language but rather a
-- language in which there is always the same number of `a`s and
-- `b`s on the left and on the right of the empty `e` symbol.
-- To model the real copy language with a TAG we would need to
-- use either adjunction constraints or feature structures.
gram2Tests :: [Test]
gram2Tests =
    [ Test "S" (words "a b e a b") Yes
    , Test "S" (words "a b e a a") No
    , Test "S" (words "a b a b a b a b e a b a b a b a b") Yes
    , Test "S" (words "a b a b a b a b e a b a b a b a  ") No
    , Test "S" (words "a b e b a") Yes
    , Test "S" (words "b e a") No
    , Test "S" (words "a b a b") No ]


---------------------------------------------------------------------
-- Grammar 3
---------------------------------------------------------------------


mkGram3 :: IO Gram
mkGram3 = compile $
    map Left [sent] ++
    map Right [xtree]
  where
    sent = INode "S"
        [ FNode "p"
        , INode "X"
            [FNode "e"]
        , FNode "b" ]
    xtree = AuxTree (INode "X"
        [ FNode "a"
        , INode "X" []
        , FNode "b" ]
        ) [1]


-- | Here we check that the auxiliary tree must be fully
-- recognized before it can be adjoined.
gram3Tests :: [Test]
gram3Tests =
    [ Test "S" (words "p a e b b") Yes
    , Test "S" (words "p a e b") No ]



---------------------------------------------------------------------
-- Grammar 4 (make a cat drink)
---------------------------------------------------------------------


make1 :: WeightedTree
make1 = ( INode "S"
    [ INode "VP"
        [ INode "V" [FNode "make"]
        , INode "NP" [] ]
    ], 1)


make2 :: WeightedTree
make2 = ( INode "S"
    [ INode "VP"
        [ INode "V" [FNode "make"]
        , INode "NP" []
        , INode "VP" [] ]
    ], 1)


a' :: WeightedTree
a' = (INode "D" [FNode "a"], 1)


cat :: WeightedTree
cat = ( INode "NP"
    [ INode "D" []
    , INode "N"
        [FNode "cat"]
    ], 1)


drink :: WeightedTree
drink = ( INode "VP"
    [ INode "V"
        [FNode "drink"]
    ], 1)


catDrink :: WeightedTree
catDrink = ( INode "NP"
    [ INode "D" []
    , INode "N"
        [FNode "cat"]
    , INode "N"
        [FNode "drink"]
    ], 0)


-- | Compile the first grammar.
mkGram4 :: IO WeightedGram
mkGram4 = W.compileWeights $
    map Left
        [ make1, make2, a', cat
        , drink, catDrink ] -- ++
    -- map Right [almost, quickly]


-- | Here we check that the auxiliary tree must be fully
-- recognized before it can be adjoined.
gram4Tests :: [Test]
gram4Tests =
    [ Test "S" ["make", "a", "cat", "drink"] . WeightedTrees $ M.fromList
        [ ( INode "S"
          [ INode "VP"
            [ INode "V" [FNode "make"]
            , INode "NP"
              [ INode "D" [FNode "a"]
              , INode "N" [FNode "cat"] ]
            , INode "VP"
              [ INode "V" [FNode "drink"] ]
            ]
          ], 4)
        , ( INode "S"
          [ INode "VP"
            [ INode "V" [FNode "make"]
            , INode "NP"
              [ INode "D" [FNode "a"]
              , INode "N" [FNode "cat"]
              , INode "N" [FNode "drink"] ]
            ]
          ], 2)
        ]
    ]


---------------------------------------------------------------------
-- Resources
---------------------------------------------------------------------


-- | Compiled grammars.
data Res = Res
    { gram1 :: Gram
    , gram2 :: Gram
    , gram3 :: Gram
    , gram4 :: WeightedGram }


-- | Construct the shared resource (i.e. the grammars) used in
-- tests.
mkGrams :: IO Res
mkGrams = Res <$> mkGram1 <*> mkGram2 <*> mkGram3 <*> mkGram4


---------------------------------------------------------------------
-- Test Tree
---------------------------------------------------------------------


-- | All the tests of the parsing algorithm.
testTree
    :: String
        -- ^ Name of the tested module
    -> (Gram -> String -> [String] -> IO Bool)
        -- ^ Recognition function
    -> Maybe (Gram -> String -> [String] -> IO (S.Set Tr))
        -- ^ Parsing function (optional)
    -> Maybe (WeightedGram -> String -> [String] -> IO (M.Map Tr Cost))
        -- ^ Parsing with weights (optional)
    -> TestTree
testTree modName reco parse parseW = withResource mkGrams (const $ return ()) $
    \resIO -> testGroup modName $
        map (testIt resIO gram1) gram1Tests ++
        map (testIt resIO gram2) gram2Tests ++
        map (testIt resIO gram3) gram3Tests ++
        map (testWe resIO gram4) gram4Tests
  where
    testIt resIO getGram test = testCase (show test) $ do
        gram <- getGram <$> resIO
        doTest gram test
    testWe resIO getGram test = testCase (show test) $ do
        gram <- getGram <$> resIO
        doTestW gram test

    doTest gram test@Test{..} = case (parse, testRes) of
        (Nothing, _) ->
            reco gram startSym testSent @@?= simplify testRes
        (Just pa, Trees ts) ->
            pa gram startSym testSent @@?= ts
        _ ->
            reco gram startSym testSent @@?= simplify testRes

    doTestW gram test@Test{..} = case (parseW, parse, testRes) of
--         (Nothing, Nothing, _) ->
--             reco gram startSym testSent @@?= simplify testRes
        (_, Just pa, Trees ts) ->
            pa (unWeighGram gram) startSym testSent @@?= ts
        (Just pa, _, WeightedTrees ts) ->
            fmap smoothOut (pa gram startSym testSent) @@?= ts
        (Nothing, Just pa, WeightedTrees ts) ->
            pa (unWeighGram gram) startSym testSent @@?= remWeights ts
        _ ->
            reco (unWeighGram gram) startSym testSent @@?= simplify testRes

    smoothOut = fmap $ roundWeight 5
    roundWeight n x = fromInteger (round $ x * (10^n)) / (10.0^^n)

    remWeights = M.keysSet
    unWeighGram
        = S.fromList
        . map W.unWeighRule
        . S.toList

    simplify No         = False
    simplify Yes        = True
    simplify (Trees _)  = True
    simplify (WeightedTrees _)
                        = True

---------------------------------------------------------------------
-- Utils
---------------------------------------------------------------------


(@@?=) :: (Show a, Eq a) => IO a -> a -> Assertion
mx @@?= y = do
    x <- mx
    x @?= y
