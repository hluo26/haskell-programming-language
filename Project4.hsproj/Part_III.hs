{-# LANGUAGE GADTs #-}

module Part_III where

-- Imports for QuickCheck
import System.Random
import Test.QuickCheck
import Test.QuickCheck.Gen
import Test.QuickCheck.Function
import Test.QuickCheck.Monadic

-- Imports for Parsec
import Control.Monad
import Text.ParserCombinators.Parsec
import Text.ParserCombinators.Parsec.Language
import Text.ParserCombinators.Parsec.Expr
import Text.ParserCombinators.Parsec.Token

-- Imports for PLIH
import ParserUtils

--
-- Project utilities for developing CFAE and CFBAE
-- interpreters.
--
-- Author: Perry Alexander
-- Date: 6 April 2017
--

-- CFAE AST Definition

data CFAE where
  Num :: Int -> CFAE
  Plus :: CFAE -> CFAE -> CFAE
  Minus :: CFAE -> CFAE -> CFAE
  Mult :: CFAE -> CFAE -> CFAE
  Div :: CFAE -> CFAE -> CFAE
  Lambda :: String -> CFAE -> CFAE
  App :: CFAE -> CFAE -> CFAE
  Id :: String -> CFAE
  If :: CFAE -> CFAE -> CFAE -> CFAE
  deriving (Show,Eq)

-- Parser

expr :: Parser CFAE
expr = buildExpressionParser opTable term

opTable = [ [ inFix "*" Mult AssocLeft
            , inFix "/" Div AssocLeft ]
          , [ inFix "+" Plus AssocLeft
            , inFix "-" Minus AssocLeft ]
          ]

numExpr :: Parser CFAE
numExpr = do i <- integer lexer
             return (Num (fromInteger i))

identExpr :: Parser CFAE
identExpr = do i <- identifier lexer
               return (Id i)
              
lambdaExpr :: Parser CFAE
lambdaExpr = do reserved lexer "lambda"
                i <- identifier lexer
                reserved lexer "in"
                e <- expr
                return (Lambda i e)

appExpr :: Parser CFAE
appExpr = do reserved lexer "app"
             e1 <- expr
             e2 <- expr
             return (App e1 e2)

ifExpr :: Parser CFAE
ifExpr = do reserved lexer "if"
            c <- expr
            reserved lexer "then"
            t <- expr
            reserved lexer "else"
            e <- expr
            return (If c t e)
            
             
term = parens lexer expr
       <|> numExpr
       <|> identExpr
       <|> ifExpr
       <|> lambdaExpr
       <|> appExpr
             
-- Parser invocation

parseCFAE = parseString expr

parseCFAEFile = parseFile expr


-- CFBAE Parser

-- CFBAE AST Definition

data CFBAE where
  NumX :: Int -> CFBAE
  PlusX :: CFBAE -> CFBAE -> CFBAE
  MinusX :: CFBAE -> CFBAE -> CFBAE
  MultX :: CFBAE -> CFBAE -> CFBAE
  DivX :: CFBAE -> CFBAE -> CFBAE
  BindX :: String -> CFBAE -> CFBAE -> CFBAE
  LambdaX :: String -> CFBAE -> CFBAE
  AppX :: CFBAE -> CFBAE -> CFBAE
  IdX :: String -> CFBAE
  IfX :: CFBAE -> CFBAE -> CFBAE -> CFBAE
  deriving (Show,Eq)

-- Parser

exprX :: Parser CFBAE
exprX = buildExpressionParser opTableX termX

opTableX = [ [ inFix "*" MultX AssocLeft
            , inFix "/" DivX AssocLeft ]
          , [ inFix "+" PlusX AssocLeft
            , inFix "-" MinusX AssocLeft ]
          ]

numExprX :: Parser CFBAE
numExprX = do i <- integer lexer
              return (NumX (fromInteger i))

identExprX :: Parser CFBAE
identExprX = do i <- identifier lexer
                return (IdX i)

bindExprX :: Parser CFBAE
bindExprX = do reserved lexer "bind"
               i <- identifier lexer
               reservedOp lexer "="
               v <- exprX
               reserved lexer "in"
               e <- exprX
               return (BindX i v e)
              
lambdaExprX :: Parser CFBAE
lambdaExprX = do reserved lexer "lambda"
                 i <- identifier lexer
                 reserved lexer "in"
                 e <- exprX
                 return (LambdaX i e)

appExprX :: Parser CFBAE
appExprX = do reserved lexer "app"
              e1 <- exprX
              e2 <- exprX
              return (AppX e1 e2)

ifExprX :: Parser CFBAE
ifExprX = do reserved lexer "if"
             c <- exprX
             reserved lexer "then"
             t <- exprX
             reserved lexer "else"
             e <- exprX
             return (IfX c t e)
            
             
termX = parens lexer exprX
       <|> numExprX
       <|> identExprX
       <|> bindExprX
       <|> ifExprX
       <|> lambdaExprX
       <|> appExprX
             
-- Parser invocation

parseCFBAE = parseString exprX

parseCFBAEFile = parseFile exprX

data CFAEVal where
  NumV :: Int -> CFAEVal
  ClosureV :: String -> CFBAE -> Env -> CFAEVal
  LambdaV :: String -> CFBAE -> CFAEVal
  deriving (Show,Eq)

-- Q3 --

type Env = [(String,CFAEVal)]

elabCFBAE :: CFBAE -> CFAE

elabCFBAE (NumX x) = (Num x)

elabCFBAE (PlusX x y) = (Plus (elabCFBAE x)(elabCFBAE y))

elabCFBAE (MinusX x y) = (Minus (elabCFBAE x)(elabCFBAE y))

elabCFBAE (MultX x y) = (Mult (elabCFBAE x)(elabCFBAE y))

elabCFBAE (DivX x y) = (Div (elabCFBAE x)(elabCFBAE y))

elabCFBAE (BindX i b e) = (App (Lambda i (elabCFBAE e)) (elabCFBAE b))

elabCFBAE (LambdaX x y) = (Lambda x (elabCFBAE y))

elabCFBAE (AppX x y) = let (Lambda i b) = (elabCFBAE x)
                           a = (elabCFBAE y)
                          in (App (Lambda i b) a)
                          
elabCFBAE (IdX x) = (Id x)

elabCFBAE (IfX x y z) = (If (elabCFBAE x) (elabCFBAE y) (elabCFBAE z))


-- eval --

evalCFBAE :: Env -> CFBAE -> CFAEVal

evalCFBAE env (NumX x) = (NumV x)

evalCFBAE env (PlusX x y) = let (NumV t1) = (evalCFBAE env x)
                                (NumV t2) = (evalCFBAE env y)
                             in (NumV (t1 + t2))
                             
evalCFBAE env (MinusX x y) = let (NumV t1) = (evalCFBAE env x)
                                 (NumV t2) = (evalCFBAE env y)
                             in (NumV (t1 - t2))

evalCFBAE env (MultX x y) = let (NumV t1) = (evalCFBAE env x)
                                (NumV t2) = (evalCFBAE env y)
                             in (NumV (t1 * t2))
                             
evalCFBAE env (DivX x y) = let (NumV t1) = (evalCFBAE env x)
                               (NumV t2) = (evalCFBAE env y)
                             in (NumV (div t1 t2))
                             
evalCFBAE env (BindX i b e) = evalCFBAE((i,(evalCFBAE env b)):env)e

evalCFBAE env (LambdaX i b) = (ClosureV i b env)

evalCFBAE env (AppX x y) = let (ClosureV i b env) = (evalCFBAE env x)
                               a = (evalCFBAE env y)
                            in evalCFBAE((i,a):env)b
                            
evalCFBAE env (IdX x) = case (lookup x env) of
                        Just x -> x
                        Nothing -> error "Varible not found"
                        
evalCFBAE env (IfX x y z) = let (NumV t1) = (evalCFBAE env x)
                              in if t1==0 then (evalCFBAE env y) else (evalCFBAE env z)
 

interpCFBAE :: String -> CFAEVal

interpCFBAE = evalCFBAE[] . parseCFBAE