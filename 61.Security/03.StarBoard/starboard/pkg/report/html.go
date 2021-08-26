package report

import (
	"context"
	"fmt"
	"io"
	"sort"

	"github.com/aquasecurity/starboard/pkg/apis/aquasecurity/v1alpha1"
	"github.com/aquasecurity/starboard/pkg/configauditreport"
	clientset "github.com/aquasecurity/starboard/pkg/generated/clientset/versioned"
	"github.com/aquasecurity/starboard/pkg/kube"
	"github.com/aquasecurity/starboard/pkg/report/templates"
	"github.com/aquasecurity/starboard/pkg/vulnerabilityreport"
)

type htmlReporter struct {
	vulnerabilityReportsReader vulnerabilityreport.ReadWriter
	configAuditReportsReader   configauditreport.ReadWriter
}

func NewHTMLReporter(starboardClientset clientset.Interface) Reporter {
	return &htmlReporter{
		vulnerabilityReportsReader: vulnerabilityreport.NewReadWriter(starboardClientset),
		configAuditReportsReader:   configauditreport.NewReadWriter(starboardClientset),
	}
}

func (h *htmlReporter) GenerateReport(workload kube.Object, writer io.Writer) error {
	ctx := context.Background()
	configAuditReport, err := h.configAuditReportsReader.FindByOwner(ctx, workload)
	if err != nil {
		return err
	}
	vulnerabilityReports, err := h.vulnerabilityReportsReader.FindByOwner(ctx, workload)
	if err != nil {
		return err
	}

	vulnsReports := map[string]v1alpha1.VulnerabilityScanResult{}
	for _, vulnerabilityReport := range vulnerabilityReports {
		containerName, ok := vulnerabilityReport.Labels[kube.LabelContainerName]
		if !ok {
			continue
		}

		sort.Stable(vulnerabilityreport.BySeverity{Vulnerabilities: vulnerabilityReport.Report.Vulnerabilities})

		vulnsReports[containerName] = vulnerabilityReport.Report
	}
	if configAuditReport == nil && len(vulnsReports) == 0 {
		return fmt.Errorf("no configaudits or vulnerabilities found for workload %s/%s/%s",
			workload.Namespace, workload.Kind, workload.Name)
	}

	templates.WritePageTemplate(writer, &templates.ReportPage{
		VulnsReports:      vulnsReports,
		ConfigAuditReport: configAuditReport,
		Workload:          workload,
	})
	return nil
}
