package operator

import (
	"context"
	"fmt"

	"github.com/aquasecurity/starboard/pkg/config"
	"github.com/aquasecurity/starboard/pkg/configauditreport"
	"github.com/aquasecurity/starboard/pkg/kube"
	"github.com/aquasecurity/starboard/pkg/operator/controller"
	"github.com/aquasecurity/starboard/pkg/operator/etc"
	"github.com/aquasecurity/starboard/pkg/starboard"
	"github.com/aquasecurity/starboard/pkg/vulnerabilityreport"
	"k8s.io/client-go/kubernetes"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/cache"
	"sigs.k8s.io/controller-runtime/pkg/healthz"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/manager"
)

var (
	setupLog = log.Log.WithName("operator")
)

func Run(buildInfo starboard.BuildInfo, operatorConfig etc.Config) error {
	setupLog.Info("Starting operator", "buildInfo", buildInfo)

	installMode, operatorNamespace, targetNamespaces, err := operatorConfig.ResolveInstallMode()
	if err != nil {
		return fmt.Errorf("resolving install mode: %w", err)
	}
	setupLog.Info("Resolved install mode", "install mode", installMode,
		"operator namespace", operatorNamespace,
		"target namespaces", targetNamespaces)

	// Set the default manager options.
	options := manager.Options{
		Scheme:                 starboard.NewScheme(),
		MetricsBindAddress:     operatorConfig.MetricsBindAddress,
		HealthProbeBindAddress: operatorConfig.HealthProbeBindAddress,
	}

	switch installMode {
	case etc.OwnNamespace:
		// Add support for OwnNamespace set in OPERATOR_NAMESPACE (e.g. `starboard-operator`)
		// and OPERATOR_TARGET_NAMESPACES (e.g. `starboard-operator`).
		setupLog.Info("Constructing client cache", "namespace", targetNamespaces[0])
		options.Namespace = targetNamespaces[0]
	case etc.SingleNamespace:
		// Add support for SingleNamespace set in OPERATOR_NAMESPACE (e.g. `starboard-operator`)
		// and OPERATOR_TARGET_NAMESPACES (e.g. `default`).
		cachedNamespaces := append(targetNamespaces, operatorNamespace)
		setupLog.Info("Constructing client cache", "namespaces", cachedNamespaces)
		options.Namespace = targetNamespaces[0]
		options.NewCache = cache.MultiNamespacedCacheBuilder(cachedNamespaces)
	case etc.MultiNamespace:
		// Add support for MultiNamespace set in OPERATOR_NAMESPACE (e.g. `starboard-operator`)
		// and OPERATOR_TARGET_NAMESPACES (e.g. `default,kube-system`).
		// Note that you may face performance issues when using this mode with a high number of namespaces.
		// More: https://godoc.org/github.com/kubernetes-sigs/controller-runtime/pkg/cache#MultiNamespacedCacheBuilder
		cachedNamespaces := append(targetNamespaces, operatorNamespace)
		setupLog.Info("Constructing client cache", "namespaces", cachedNamespaces)
		options.Namespace = ""
		options.NewCache = cache.MultiNamespacedCacheBuilder(cachedNamespaces)
	case etc.AllNamespaces:
		// Add support for AllNamespaces set in OPERATOR_NAMESPACE (e.g. `operators`)
		// and OPERATOR_TARGET_NAMESPACES left blank.
		setupLog.Info("Watching all namespaces")
		options.Namespace = ""
	default:
		return fmt.Errorf("unrecognized install mode: %v", installMode)
	}

	kubeConfig, err := ctrl.GetConfig()
	if err != nil {
		return fmt.Errorf("getting kube client config: %w", err)
	}

	// The only reason we're using kubernetes.Clientset is that we need it to read Pod logs,
	// which is not supported by the client returned by the ctrl.Manager.
	kubeClientset, err := kubernetes.NewForConfig(kubeConfig)
	if err != nil {
		return fmt.Errorf("constructing kube client: %w", err)
	}

	mgr, err := ctrl.NewManager(kubeConfig, options)
	if err != nil {
		return fmt.Errorf("constructing controllers manager: %w", err)
	}

	err = mgr.AddReadyzCheck("ping", healthz.Ping)
	if err != nil {
		return err
	}

	err = mgr.AddHealthzCheck("ping", healthz.Ping)
	if err != nil {
		return err
	}

	configManager := starboard.NewConfigManager(kubeClientset, operatorNamespace)
	err = configManager.EnsureDefault(context.Background())
	if err != nil {
		return err
	}

	starboardConfig, err := configManager.Read(context.Background())
	if err != nil {
		return err
	}

	ownerResolver := controller.OwnerResolver{Client: mgr.GetClient()}
	limitChecker := controller.NewLimitChecker(operatorConfig, mgr.GetClient())
	logsReader := kube.NewLogsReader(kubeClientset)
	secretsReader := kube.NewControllerRuntimeSecretsReader(mgr.GetClient())

	vulnerabilityReportPlugin, err := config.GetVulnerabilityReportPlugin(buildInfo, starboardConfig)
	if err != nil {
		return err
	}

	if err = (&controller.VulnerabilityReportReconciler{
		Logger:        ctrl.Log.WithName("reconciler").WithName("vulnerabilityreport"),
		Config:        operatorConfig,
		Client:        mgr.GetClient(),
		OwnerResolver: ownerResolver,
		LimitChecker:  limitChecker,
		LogsReader:    logsReader,
		SecretsReader: secretsReader,
		Plugin:        vulnerabilityReportPlugin,
		ReadWriter:    vulnerabilityreport.NewControllerRuntimeReadWriter(mgr.GetClient()),
	}).SetupWithManager(mgr); err != nil {
		return fmt.Errorf("unable to setup vulnerabilityreport reconciler: %w", err)
	}

	configAuditReportPlugin, err := config.GetConfigAuditReportPlugin(buildInfo, starboardConfig)
	if err != nil {
		return err
	}

	if err = (&controller.ConfigAuditReportReconciler{
		Logger:        ctrl.Log.WithName("reconciler").WithName("configauditreport"),
		Config:        operatorConfig,
		Client:        mgr.GetClient(),
		OwnerResolver: ownerResolver,
		LimitChecker:  limitChecker,
		LogsReader:    logsReader,
		Plugin:        configAuditReportPlugin,
		ReadWriter:    configauditreport.NewControllerRuntimeReadWriter(mgr.GetClient()),
	}).SetupWithManager(mgr); err != nil {
		return fmt.Errorf("unable to setup configauditreport reconciler: %w", err)
	}

	setupLog.Info("Starting controllers manager")
	if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
		return fmt.Errorf("starting controllers manager: %w", err)
	}

	return nil
}
