{-# LANGUAGE OverloadedStrings #-}

module Includes.Fields (
  postCtx,
  mathCtx,
  tagsCtx
) where

import Data.Monoid (mappend)
import Hakyll
import qualified Data.Map as M

postCtx :: Context String
postCtx = dateField "date" "%b %e, %Y" `mappend` defaultContext


mathCtx :: Context a
mathCtx = field "mathjax" $ \item -> do
    metadata <- getMetadata $ itemIdentifier item
    return $ if "mathjax" `M.member` metadata
                  then "<script type=\"text/javascript\" src=\"https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML\"></script>"
                  else ""

tagsCtx :: Tags -> Context String
tagsCtx tags = categoryField "categories" tags `mappend` postCtx

