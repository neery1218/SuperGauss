library(SuperGauss)
library(mvtnorm)
library(numDeriv)
source("SuperGauss-test-functions.R")
context("Gradient")

# ok construct a nice example
# acf(t, theta): sigma^2 * matern (t, lambda, nu)
# mu(t, lambda, gamma) = lambda * sin(gamma * t)
# theta = (gamma, lambda, nu, sigma)

acf.fun <- function(tseq, theta) {
  theta[4]^2 * matern.acf(tseq = tseq, lambda = theta[2], nu = theta[3])
}
mu.fun <- function(tseq, theta) {
  theta[2] * sin(theta[1] * tseq)
}
dacf.fun <- function(tseq, theta) {
  jacobian(acf.fun, theta, tseq = tseq)
}
dmu.fun <- function(tseq, theta) {
  jacobian(mu.fun, theta, tseq = tseq)
}

test_that("Snorm.grad and numerical deriv. of dmvnorm agree", {
  case.par <- expand.grid(N = sample(10:30, 10, replace = TRUE),
                          miss = c("mu", "dmu", "dacf", "none"))
  for(ii in 1:nrow(case.par)) {
    N <- case.par$N[ii]
    miss <- as.character(case.par$miss[ii])
    theta0 <- runif(4, min = .75, max = 1.25)
    dT <- runif(1, min = .75, max = 1.25)
    tseq <- (1:N-1)*dT
    if(miss == "none") {
      loglik.mvn <- function(theta, X, tseq) {
        dmvnorm(x = X, mean = mu.fun(tseq, theta),
                sigma = toeplitz(acf.fun(tseq, theta)), log = TRUE)
      }
      X <- rmvnorm(n = 1, mean = mu.fun(tseq, theta0),
                   sigma = toeplitz(acf.fun(tseq, theta0)))[1,]
      ngrad <- grad(loglik.mvn, theta0, tseq = tseq, X = X)
      agrad <- Snorm.grad(X = X, mu = mu.fun(tseq, theta0),
                          acf = acf.fun(tseq, theta0),
                          dmu = dmu.fun(tseq, theta0),
                          dacf = dacf.fun(tseq, theta0))
    } else if(miss == "dacf") {
      acf <- acf.fun(tseq, theta0)
      loglik.mvn <- function(theta, X, tseq) {
        dmvnorm(x = X, mean = mu.fun(tseq, theta),
                sigma = toeplitz(acf), log = TRUE)
      }
      X <- rmvnorm(n = 1, mean = mu.fun(tseq, theta0),
                   sigma = toeplitz(acf))[1,]
      ngrad <- grad(loglik.mvn, theta0, tseq = tseq, X = X)
      agrad <- Snorm.grad(X = X, mu = mu.fun(tseq, theta0),
                          acf = acf.fun(tseq, theta0),
                          dmu = dmu.fun(tseq, theta0))
    } else if(miss == "dmu") {
      mu <- mu.fun(tseq, theta0)
      loglik.mvn <- function(theta, X, tseq) {
        dmvnorm(x = X, mean = mu,
                sigma = toeplitz(acf.fun(tseq, theta)), log = TRUE)
      }
      X <- rmvnorm(n = 1, mean = mu,
                   sigma = toeplitz(acf.fun(tseq, theta0)))[1,]
      ngrad <- grad(loglik.mvn, theta0, tseq = tseq, X = X)
      agrad <- Snorm.grad(X = X, mu = mu.fun(tseq, theta0),
                          acf = acf.fun(tseq, theta0),
                          dacf = dacf.fun(tseq, theta0))
    } else if(miss == "mu") {
      loglik.mvn <- function(theta, X, tseq) {
        dmvnorm(x = X, sigma = toeplitz(acf.fun(tseq, theta)), log = TRUE)
      }
      X <- rmvnorm(n = 1, sigma = toeplitz(acf.fun(tseq, theta0)))[1,]
      ngrad <- grad(loglik.mvn, theta0, tseq = tseq, X = X)
      agrad <- Snorm.grad(X = X,
                          acf = acf.fun(tseq, theta0),
                          dacf = dacf.fun(tseq, theta0))
    }
    expect_equal(ngrad, agrad)
  }
})
