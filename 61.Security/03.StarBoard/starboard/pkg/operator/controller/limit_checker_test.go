package controller_test

import (
	"context"

	"github.com/aquasecurity/starboard/pkg/kube"
	"github.com/aquasecurity/starboard/pkg/operator/controller"
	"github.com/aquasecurity/starboard/pkg/operator/etc"
	"github.com/aquasecurity/starboard/pkg/starboard"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	batchv1 "k8s.io/api/batch/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"sigs.k8s.io/controller-runtime/pkg/client/fake"
)

var _ = Describe("LimitChecker", func() {

	config := etc.Config{
		Namespace:               "starboard-operator",
		ConcurrentScanJobsLimit: 2,
	}

	Context("When there are more jobs than limit", func() {

		It("Should return true", func() {

			client := fake.NewClientBuilder().WithScheme(starboard.NewScheme()).WithObjects(
				&batchv1.Job{ObjectMeta: metav1.ObjectMeta{
					Name:      "logs-exporter",
					Namespace: "starboard-operator",
				}},
				&batchv1.Job{ObjectMeta: metav1.ObjectMeta{
					Name:      "scan-vulnerabilityreport-hash1",
					Namespace: "starboard-operator",
					Labels: map[string]string{
						kube.LabelK8SAppManagedBy: kube.AppStarboardOperator,
					},
				}},
				&batchv1.Job{ObjectMeta: metav1.ObjectMeta{
					Name:      "scan-vulnerabilityreport-hash2",
					Namespace: "starboard-operator",
					Labels: map[string]string{
						kube.LabelK8SAppManagedBy: kube.AppStarboardOperator,
					},
				}},
				&batchv1.Job{ObjectMeta: metav1.ObjectMeta{
					Name:      "scan-configauditreport-hash2",
					Namespace: "starboard-operator",
					Labels: map[string]string{
						kube.LabelK8SAppManagedBy: kube.AppStarboardOperator,
					},
				}},
			).Build()

			instance := controller.NewLimitChecker(config, client)
			limitExceeded, jobsCount, err := instance.Check(context.TODO())
			Expect(err).ToNot(HaveOccurred())
			Expect(limitExceeded).To(BeTrue())
			Expect(jobsCount).To(Equal(3))
		})

	})

	Context("When there are less jobs than limit", func() {

		It("Should return false", func() {
			client := fake.NewClientBuilder().WithScheme(starboard.NewScheme()).WithObjects(
				&batchv1.Job{ObjectMeta: metav1.ObjectMeta{
					Name:      "logs-exporter",
					Namespace: "starboard-operator",
				}},
				&batchv1.Job{ObjectMeta: metav1.ObjectMeta{
					Name:      "scan-vulnerabilityreport-hash1",
					Namespace: "starboard-operator",
					Labels: map[string]string{
						kube.LabelK8SAppManagedBy: kube.AppStarboardOperator,
					},
				}},
			).Build()

			instance := controller.NewLimitChecker(config, client)
			limitExceeded, jobsCount, err := instance.Check(context.TODO())
			Expect(err).ToNot(HaveOccurred())
			Expect(limitExceeded).To(BeFalse())
			Expect(jobsCount).To(Equal(1))
		})

	})
})
